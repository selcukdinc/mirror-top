import Foundation
import ScreenCaptureKit
import CoreMedia
import AppKit

@MainActor
public final class StreamManager: NSObject, Sendable {
    public static let shared = StreamManager()
    
    private var stream: SCStream?
    private var activePanel: FloatingPanel?
    private var previewView: CapturePreviewView?
    private var capturedWindowID: CGWindowID?
    private var frameCount = 0
    private var originalWindowInfo: FocusedWindowInfo?
    private var lastPanelResizeTime: Date = Date()
    private var consecutiveRestarts = 0
    private var lastRestartTime = Date.distantPast
    /// SCStream config'ine en son yazılan içerik boyutu (points). Window resize sırasında
    /// `updateConfiguration` çağrısının gerekip gerekmediğine karar vermek için kullanılır.
    private var lastConfiguredSize: CGSize = .zero
    
    public var interactionMode: Bool = false {
        didSet {
            activePanel?.interactionMode = interactionMode
            previewView?.interactionMode = interactionMode
            print(">>> [StreamManager] Etkileşim Modu değiştirildi: \(interactionMode ? "AÇIK" : "KAPALI")")
        }
    }
    
    public var isCapturing: Bool {
        return stream != nil
    }
    
    private override init() {
        super.init()
    }
    
    /// Kısayola basıldığında tetiklenen Toggle (Aç/Kapat) mantığı.
    public func toggleCapture(windowInfo: FocusedWindowInfo) async throws {
        // Güvenlik ağı: Kendi PID'mize ait pencereyi yakalamayı reddet (recursive capture -> crash).
        let ourPID = ProcessInfo.processInfo.processIdentifier
        if windowInfo.pid == ourPID {
            print(">>> [StreamManager] Kendi penceremizi yakalama isteği reddedildi (recursive capture koruması).")
            return
        }
        
        if isCapturing {
            if capturedWindowID == windowInfo.cgWindowID {
                // Aynı pencereye tıklandıysa veya kısayola basıldıysa kapat.
                await stopCapture()
                return
            } else {
                // Başka pencere için kısayola basıldıysa öncekini kapat, yenisini aç.
                await stopCapture()
            }
        }
        
        try await startCapture(for: windowInfo)
    }
    
    /// Etkileşim modunu (Interaction Mode) açıp kapatır.
    public func toggleInteractionMode() {
        guard isCapturing else { return }
        interactionMode.toggle()
    }
    
    /// Pencereyi yakalamayı başlatır.
    private func startCapture(for windowInfo: FocusedWindowInfo) async throws {
        // onScreenWindowsOnly: false yapıyoruz ki pencere başka bir masaüstüne (Space) geçse bile onu bulabilelim.
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let scWindow = shareableContent.windows.first(where: { $0.windowID == windowInfo.cgWindowID }) else {
            print("Hata: Pencere ScreenCaptureKit içeriklerinde bulunamadı.")
            return
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = makeConfig(forContentSize: windowInfo.frame.size)
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        
        // Sample handler kuyruğu (performans için arka planda işlenecek)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        
        self.stream = newStream
        self.capturedWindowID = windowInfo.cgWindowID
        self.originalWindowInfo = windowInfo
        self.lastConfiguredSize = windowInfo.frame.size
        
        // Paneli hazırlayıp ekranda göster
        setupPanel(for: windowInfo)
        
        // MirrorRegistry'ye kaydet (Dock-mode için).
        if let app = NSRunningApplication(processIdentifier: windowInfo.pid),
           let bundleID = app.bundleIdentifier {
            let panelFrame = activePanel?.frame ?? windowInfo.frame
            MirrorRegistry.shared.registerActive(bundleID: bundleID,
                                                 appName: windowInfo.appName,
                                                 title: windowInfo.title,
                                                 frame: panelFrame)
        }
        
        // Varsayılan olarak View Only (İzleme) modu ile başlat
        self.interactionMode = false
        
        try await newStream.startCapture()
    }
    
    /// Verilen içerik (pencere) boyutuna uygun SCStreamConfiguration üretir.
    /// Buffer = pencere içeriği × scale → render edilecek görüntü kaynak pencereyle birebir.
    private func makeConfig(forContentSize size: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        // Minimum 1 pixel — sıfır boyut SCStream tarafından reddedilir.
        config.width = max(1, Int((size.width * scale).rounded()))
        config.height = max(1, Int((size.height * scale).rounded()))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        if #available(macOS 14.0, *) {
            config.ignoreShadowsSingleWindow = true
        }
        return config
    }
    
    /// Kaynak pencerenin boyutu değiştiğinde (contentRect.size) çağrılır.
    /// Stream config'ini yeni boyuta günceller, panel aspect-ratio'sunu yeniler ve
    /// kullanıcının manuel verdiği panel WIDTH'i koruyarak HEIGHT'ı yeni aspect'e adapte eder.
    /// Throttling: saniyede ~10 kez. Panel ORIGIN'i hiçbir zaman bu metoddan değişmez (sallanmayı engeller).
    private func handleContentResizeIfNeeded(newSize: CGSize) {
        guard newSize.width > 1, newSize.height > 1 else { return }
        let last = lastConfiguredSize
        let widthDiff = abs(last.width - newSize.width)
        let heightDiff = abs(last.height - newSize.height)
        // 2 pixel altındaki gürültüye reaksiyon verme.
        if widthDiff < 2 && heightDiff < 2 { return }
        
        let now = Date()
        if now.timeIntervalSince(lastPanelResizeTime) < 0.1 { return }
        lastPanelResizeTime = now
        
        lastConfiguredSize = newSize
        originalWindowInfo?.frame.size = newSize
        previewView?.originalWindowFrame.size = newSize
        
        // SCStream config'i güncelle — buffer artık yeni boyutta gelecek.
        if let stream = self.stream {
            let newConfig = makeConfig(forContentSize: newSize)
            Task {
                do {
                    try await stream.updateConfiguration(newConfig)
                } catch {
                    print(">>> [StreamManager] updateConfiguration başarısız: \(error.localizedDescription)")
                }
            }
        }
        
        // Panel aspect'ini içeriğe kilitle ve YÜKSEKLİĞİ width'e göre yeniden hesapla.
        // (Width kullanıcı tarafından belirleniyor olabilir; ona dokunmuyoruz.)
        if let panel = activePanel {
            panel.aspectRatio = newSize
            panel.contentAspectRatio = newSize
            
            let aspect = newSize.width / newSize.height
            var frame = panel.frame
            let newHeight = frame.width / aspect
            // Top-left sabit: origin.y'yi yeni yüksekliğe göre ayarla.
            frame.origin.y = frame.maxY - newHeight
            frame.size.height = newHeight
            panel.setFrame(frame, display: false, animate: false)
        }
    }
    
    /// PiP paneli aktifse en öne getirir (Dock-mode'dan tıklanınca kullanılır).
    public func bringActivePanelToFront() {
        activePanel?.orderFrontRegardless()
    }
    
    /// Yayını güvenli bir şekilde durdurur ve paneli kapatarak bellek sızıntılarını önler.
    public func stopCapture() async {
        // Registry'ye inactive olarak işaretle (Dock-mode geçmişte tutmaya devam eder).
        if let info = self.originalWindowInfo,
           let app = NSRunningApplication(processIdentifier: info.pid),
           let bundleID = app.bundleIdentifier {
            MirrorRegistry.shared.markInactive(bundleID: bundleID, title: info.title)
        }
        // 1) Önce yeniden-başlatma akışının elinden bilgiyi alıyoruz.
        //    Bu sayede stopCapture sırasında didStopWithError tetiklense bile lastWindowInfo nil olur,
        //    auto-restart loop'u çalışmaz.
        self.originalWindowInfo = nil
        self.capturedWindowID = nil
        
        if let currentStream = stream {
            // 2) Output'u kaldırıp yeni karelerin gelmesini durduruyoruz.
            //    Aksi halde stopCapture await ederken kuyrukta sıkışmış kareler hâlâ
            //    main thread'e enqueue edilebiliyor ve panel deallocation ile çakışıp crash üretebiliyor.
            try? currentStream.removeStreamOutput(self, type: .screen)
            
            do {
                try await currentStream.stopCapture()
            } catch {
                print("Yayın durdurulurken hata oluştu: \(error)")
            }
        }
        
        self.stream = nil
        
        closePanel()
    }
    
    /// Sessiz yeniden başlatma — paneli ve previewView'i KORUR, sadece alttaki SCStream'i yeniden oluşturur.
    /// macOS bazen 5-6 dakika sonra ScreenCaptureKit yayınını sistem tarafından öldürüyor;
    /// kullanıcı flicker görmesin diye paneli kapatmadan stream'i yeniden bağlıyoruz.
    /// Son kare CALayer.contents'te kalır, yeni stream başlayınca render kaldığı yerden devam eder.
    private func silentRestart(for windowInfo: FocusedWindowInfo) async throws {
        // Eski stream'i temizle (panel/previewView'e DOKUNMA).
        if let oldStream = self.stream {
            try? oldStream.removeStreamOutput(self, type: .screen)
            try? await oldStream.stopCapture()
        }
        self.stream = nil
        
        // Pencere hâlâ var mı?
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let scWindow = shareableContent.windows.first(where: { $0.windowID == windowInfo.cgWindowID }) else {
            print(">>> [StreamManager] Sessiz restart: pencere artık mevcut değil (ID: \(windowInfo.cgWindowID)).")
            throw NSError(domain: "MirrorTop", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Hedef pencere bulunamadı"])
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = makeConfig(forContentSize: windowInfo.frame.size)
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen,
                                      sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        
        self.stream = newStream
        self.capturedWindowID = windowInfo.cgWindowID
        self.originalWindowInfo = windowInfo
        self.lastConfiguredSize = windowInfo.frame.size
        // NOT: interactionMode'u SIFIRLAMIYORUZ — kullanıcının seçimi korunur.
        // NOT: Paneli ve previewView'i tutuyoruz — son kare freeze olarak kalır.
        
        try await newStream.startCapture()
        print(">>> [StreamManager] Sessiz restart başarılı. Panel pozisyonu/boyutu korundu.")
    }
    
    private func setupPanel(for windowInfo: FocusedWindowInfo) {
        if activePanel == nil {
            let panel = FloatingPanel(contentRect: windowInfo.frame)
            
            // Panelin en-boy oranını orijinal pencerenin oranına sabitle
            panel.aspectRatio = windowInfo.frame.size
            panel.contentAspectRatio = windowInfo.frame.size
            
            let view = CapturePreviewView(frame: NSRect(origin: .zero, size: windowInfo.frame.size))
            view.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(view)
            
            self.previewView = view
            self.activePanel = panel
            
            // Görünüm ayarları (opacity, ghost mode) panele uygula + observer kur.
            applyAppearance()
            NotificationCenter.default.addObserver(self, selector: #selector(onAppearanceChanged),
                                                   name: .mtAppearanceChanged, object: nil)
            // Panel taşındığında snap ve persist için bildirim al.
            NotificationCenter.default.addObserver(self, selector: #selector(panelDidMove(_:)),
                                                   name: NSWindow.didMoveNotification, object: panel)
            NotificationCenter.default.addObserver(self, selector: #selector(panelDidResize(_:)),
                                                   name: NSWindow.didResizeNotification, object: panel)
            // Ghost mode için aktif uygulama değişimini izle.
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeAppChanged),
                                                              name: NSWorkspace.didActivateApplicationNotification,
                                                              object: nil)
        }
        
        previewView?.originalWindowFrame = windowInfo.frame
        previewView?.originalPID = windowInfo.pid
        // AX üzerinden kaynak pencereyi yeniden bul; etkileşim modunda her tıkta güncel konumu okuyacağız.
        previewView?.sourceAXWindow = focusedAXWindow(forPID: windowInfo.pid)
        activePanel?.interactionMode = self.interactionMode
        previewView?.interactionMode = self.interactionMode
        
        // macOS'te AXUIElement koordinatları Top-Left (Sol Üst), NSWindow koordinatları ise Bottom-Left (Sol Alt) referanslıdır.
        // Y eksenini ters çevirerek panelin tam olarak orijinal pencerenin üzerinde açılmasını sağlıyoruz.
        var correctedFrame = windowInfo.frame
        // Orijinal pencerenin bulunduğu ekranı tespit et
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowInfo.frame) }) ?? NSScreen.main
        let screenHeight = screen?.frame.height ?? 1080
        correctedFrame.origin.y = screenHeight - windowInfo.frame.origin.y - windowInfo.frame.height
        
        // Kullanıcı bu pencere için daha önce panel pozisyonu kaydettiyse onu uygula.
        if let savedFrame = loadSavedFrame(for: windowInfo) {
            activePanel?.setFrame(savedFrame, display: true)
        } else {
            activePanel?.setFrame(correctedFrame, display: true)
        }
        activePanel?.orderFront(nil)
    }
    
    // MARK: - Görünüm uygulamaları (opacity, ghost, border)
    
    @objc private func onAppearanceChanged() {
        applyAppearance()
    }
    
    private func applyAppearance() {
        guard let panel = activePanel else { return }
        let s = SettingsManager.shared
        // Hayalet modu aktif + biz front değil isek ghostOpacity, aksi halde ana opacity.
        let isFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        if s.ghostMode && !isFront {
            panel.alphaValue = CGFloat(s.ghostOpacity)
        } else {
            panel.alphaValue = CGFloat(s.opacity)
        }
        previewView?.showInteractionBorder = s.showInteractionBorder
    }
    
    @objc private func activeAppChanged() {
        applyAppearance()
    }
    
    // MARK: - Snap & Persist
    
    @objc private func panelDidMove(_ note: Notification) {
        applySnapIfNeeded()
        persistFrameIfNeeded()
    }
    
    @objc private func panelDidResize(_ note: Notification) {
        persistFrameIfNeeded()
    }
    
    /// Panel ekran köşelerine yakınsa yapıştır (snap).
    private func applySnapIfNeeded() {
        guard SettingsManager.shared.snapToCorners,
              let panel = activePanel else { return }
        let frame = panel.frame
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let threshold: CGFloat = 24
        var newOrigin = frame.origin
        // X
        if abs(frame.minX - v.minX) <= threshold { newOrigin.x = v.minX }
        else if abs(v.maxX - frame.maxX) <= threshold { newOrigin.x = v.maxX - frame.width }
        // Y (bottom-left)
        if abs(frame.minY - v.minY) <= threshold { newOrigin.y = v.minY }
        else if abs(v.maxY - frame.maxY) <= threshold { newOrigin.y = v.maxY - frame.height }
        if newOrigin != frame.origin {
            panel.setFrameOrigin(newOrigin)
        }
    }
    
    private func persistFrameIfNeeded() {
        guard let panel = activePanel,
              let info = originalWindowInfo,
              let key = persistKey(for: info) else { return }
        SettingsManager.shared.saveFrame(panel.frame,
                                         forBundleID: key.bundleID,
                                         titleHash: key.titleHash)
    }
    
    private func loadSavedFrame(for info: FocusedWindowInfo) -> NSRect? {
        guard SettingsManager.shared.rememberPositionPerWindow,
              let key = persistKey(for: info) else { return nil }
        return SettingsManager.shared.savedFrame(forBundleID: key.bundleID, titleHash: key.titleHash)
    }
    
    private func persistKey(for info: FocusedWindowInfo) -> (bundleID: String, titleHash: String)? {
        guard let app = NSRunningApplication(processIdentifier: info.pid),
              let bundleID = app.bundleIdentifier else { return nil }
        let title = info.title
        // Stabil hash: SHA-1 yerine basit bir string formatı yeterli (UserDefaults key uzunluğu için).
        let hash = String(format: "%08x", title.hashValue & 0xFFFFFFFF)
        return (bundleID, hash)
    }
    
    // MARK: - Boyut presetleri (Cmd+Opt+1/2/3)
    
    /// PiP panelini kaynak pencerenin oranına bağlı kalarak yeniden boyutlandırır.
    /// - 1/4 (small): kaynak yüksekliğinin %25'i
    /// - 1/2 (medium): kaynak yüksekliğinin %50'si
    /// - 1:1 (large): kaynak boyutunun %100'ü
    public func applyPresetSize(_ preset: GlobalHotkeyManager.SizePreset) {
        guard let panel = activePanel,
              let info = originalWindowInfo else { return }
        let factor: CGFloat
        switch preset {
        case .small: factor = 0.25
        case .medium: factor = 0.50
        case .large: factor = 1.00
        }
        let srcW = info.frame.width
        let srcH = info.frame.height
        guard srcW > 0, srcH > 0 else { return }
        let newW = srcW * factor
        let newH = srcH * factor
        // Panel sol-üst köşesini sabit tut (kullanıcının görsel referansı bozulmasın).
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let newFrame = NSRect(x: topLeft.x,
                              y: topLeft.y - newH,
                              width: newW,
                              height: newH)
        panel.setFrame(newFrame, display: true, animate: true)
        persistFrameIfNeeded()
    }
    
    private func closePanel() {
        if let panel = activePanel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: panel)
        }
        NotificationCenter.default.removeObserver(self, name: .mtAppearanceChanged, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        activePanel?.orderOut(nil)
        activePanel = nil
        previewView = nil
    }
    
    /// Verilen PID'ye ait uygulamanın o anki odaklı (focused) penceresinin AX referansını döndürür.
    /// Etkileşim modunda kaynak pencerenin GÜNCEL ekran konumunu okumak için kullanılır
    /// (kullanıcı pencereyi taşımış olabilir).
    private func focusedAXWindow(forPID pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as! AXUIElement?
    }
}

// MARK: - SCStreamOutput & SCStreamDelegate
extension StreamManager: SCStreamOutput, SCStreamDelegate {
    
    // Video kareleri (frame) geldikçe bu fonksiyon tetiklenir. Arka planda çalışır.
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        switch type {
        case .screen:
            // ÖNEMLİ: ScreenCaptureKit kare atladığında (Frame Drop) veya sistem dar boğaza girdiğinde
            // bize piksel verisi (ImageBuffer) OLMAYAN boş bir CMSampleBuffer gönderir.
            // Bu boş veriyi AVSampleBufferDisplayLayer'a verirsek VT-DS -12902 BadDataErr ile anında çöker!
            guard let _ = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                // Bu boş (dropped) bir karedir, yoksay ve atla.
                return
            }
            
            // İşlemleri arka planda yapıp sadece UI güncellemelerini Main Thread'e atıyoruz.
            // Saniyede 60 kez Task oluşturmak bellek sızıntısına (Task exhaustion) neden oluyordu, DispatchQueue daha hafif.
            var newContentRect: CGRect?
            if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
               let attachments = attachmentsArray.first {
                if let rect = attachments[.contentRect] as? CGRect {
                    newContentRect = rect
                } else if let dict = attachments[.contentRect] as? NSDictionary {
                    newContentRect = CGRect(dictionaryRepresentation: dict as CFDictionary)
                }
            }
            
            // Swift 6: CMSampleBuffer Sendable değil; main thread'e geçişte
            // unsafe wrapper ile aktarıyoruz. Buffer thread-safe olarak retain edilmiş durumda.
            nonisolated(unsafe) let buffer = sampleBuffer
            DispatchQueue.main.async {
                self.frameCount += 1
                if self.frameCount == 1 {
                    print(">>> [StreamManager] İLK KARE GELDİ! Ekran yayını başarıyla render ediliyor.")
                }
                self.previewView?.enqueue(buffer)
                
                // Pencere boyut değişimi: SCStream config'ini canlı güncelle.
                // Bu sayede buffer DAİMA pencerenin tam boyutunda olur, kırpma matematiğine gerek kalmaz.
                if let rect = newContentRect {
                    self.handleContentResizeIfNeeded(newSize: rect.size)
                }
            }
        default:
            break
        }
    }
    
    // Yayın sırasında bir hata oluşursa veya yayın manuel dışı durursa
    nonisolated public func stream(_ stream: SCStream, didStopWithError error: Error) {
        // `stream` parametresi nonisolated, MainActor'a köprülemek için lokal kopya alıyoruz.
        let stoppedStream = stream
        Task { @MainActor in
            print(">>> [StreamManager] Yayın hatayla durdu: \(error.localizedDescription)")
            
            // Eski / zaten değiştirilmiş bir stream'in geç gelen callback'i mi?
            // (Silent restart sırasında eski stream stopCapture sonrası bu delegate'i tekrar tetikleyebiliyor.)
            guard stoppedStream === self.stream else {
                print(">>> [StreamManager] Eski stream'e ait gecikmeli hata callback'i, yoksayılıyor.")
                return
            }
            
            // Kullanıcı ekran paylaşımını manuel durdurduysa (menü çubuğundan) → tamamen kapat.
            if let scError = error as? SCStreamError, scError.code == .userStopped {
                print(">>> [StreamManager] Kullanıcı yayını bilerek durdurdu. Tamamen kapatılıyor.")
                await self.stopCapture()
                return
            }
            
            // Bilgi yoksa restart edemeyiz, kapat.
            guard let windowInfo = self.originalWindowInfo else {
                await self.stopCapture()
                return
            }
            
            // Üst üste hızlı çökme sayacı.
            let now = Date()
            if now.timeIntervalSince(self.lastRestartTime) < 2.0 {
                self.consecutiveRestarts += 1
            } else {
                self.consecutiveRestarts = 1
            }
            self.lastRestartTime = now
            
            if self.consecutiveRestarts > 3 {
                print(">>> [StreamManager] Üst üste 3 kez çökme yaşandı. Yeniden başlatma iptal edildi.")
                await self.stopCapture()
                return
            }
            
            // SESSİZ RESTART: Paneli kapatma — kullanıcı son kareyi donmuş olarak görmeye devam eder,
            // yeni SCStream başlar başlamaz render kaldığı yerden akmaya başlar.
            try? await Task.sleep(nanoseconds: 500_000_000)
            print(">>> [StreamManager] Sessiz yeniden başlatma deneniyor (Deneme: \(self.consecutiveRestarts))...")
            
            do {
                try await self.silentRestart(for: windowInfo)
            } catch {
                print(">>> [StreamManager] Sessiz restart başarısız: \(error.localizedDescription). Tamamen kapatılıyor.")
                await self.stopCapture()
            }
        }
    }
}

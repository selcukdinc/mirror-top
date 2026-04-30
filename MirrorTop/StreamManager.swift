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
        let config = SCStreamConfiguration()
        
        // Optimizasyon ayarları
        // Genişlik/yükseklik belirtmezsek SCStream pencerenin native çözünürlüğünde yakalar.
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        config.queueDepth = 5 // Bellek optimizasyonu için derinliği düşük tutuyoruz
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false // Sesi kaydetmeye gerek yok, CoreAudio hatalarını önler
        
        // ÖNEMLİ: Gölgeyi yakalamayı kapatıyoruz. Aksi halde video boyutu orijinal pencere boyutundan (gölge kadar) büyük olur!
        if #available(macOS 14.0, *) {
            config.ignoreShadowsSingleWindow = true
        }
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        
        // Sample handler kuyruğu (performans için arka planda işlenecek)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        
        self.stream = newStream
        self.capturedWindowID = windowInfo.cgWindowID
        self.originalWindowInfo = windowInfo
        
        // Paneli hazırlayıp ekranda göster
        setupPanel(for: windowInfo)
        
        // Varsayılan olarak View Only (İzleme) modu ile başlat
        self.interactionMode = false
        
        try await newStream.startCapture()
    }
    
    /// Yayını güvenli bir şekilde durdurur ve paneli kapatarak bellek sızıntılarını önler.
    public func stopCapture() async {
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
        let config = SCStreamConfiguration()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        if #available(macOS 14.0, *) {
            config.ignoreShadowsSingleWindow = true
        }
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen,
                                      sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        
        self.stream = newStream
        self.capturedWindowID = windowInfo.cgWindowID
        self.originalWindowInfo = windowInfo
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
        }
        
        previewView?.originalWindowFrame = windowInfo.frame
        previewView?.originalPID = windowInfo.pid
        activePanel?.interactionMode = self.interactionMode
        previewView?.interactionMode = self.interactionMode
        
        // macOS'te AXUIElement koordinatları Top-Left (Sol Üst), NSWindow koordinatları ise Bottom-Left (Sol Alt) referanslıdır.
        // Y eksenini ters çevirerek panelin tam olarak orijinal pencerenin üzerinde açılmasını sağlıyoruz.
        var correctedFrame = windowInfo.frame
        // Orijinal pencerenin bulunduğu ekranı tespit et
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowInfo.frame) }) ?? NSScreen.main
        let screenHeight = screen?.frame.height ?? 1080
        correctedFrame.origin.y = screenHeight - windowInfo.frame.origin.y - windowInfo.frame.height
        
        activePanel?.setFrame(correctedFrame, display: true)
        activePanel?.orderFront(nil)
    }
    
    private func closePanel() {
        activePanel?.orderOut(nil)
        activePanel = nil
        previewView = nil
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
                
                if let rect = newContentRect {
                    let oldSize = self.originalWindowInfo?.frame.size ?? rect.size
                    // 1 pikselden büyük bir değişim varsa (Floating point hatalarını önlemek için)
                    if abs(oldSize.width - rect.size.width) > 1.0 || abs(oldSize.height - rect.size.height) > 1.0 {
                        let now = Date()
                        // Performans optimizasyonu: Saniyede maksimum 30 kez yeniden boyutlandırma yap (Overload'u engellemek için)
                        if now.timeIntervalSince(self.lastPanelResizeTime) > 0.033 {
                            self.lastPanelResizeTime = now
                            
                            if let currentFrame = self.activePanel?.frame {
                                // Kullanıcının paneli ne kadar büyüttüğünü/küçülttüğünü (Scale) hesapla
                                let scale = currentFrame.width / oldSize.width
                                
                                // Yeni boyutu kullanıcının scale oranına göre uyarla
                                let newPanelSize = CGSize(width: rect.size.width * scale, height: rect.size.height * scale)
                                
                                self.originalWindowInfo?.frame.size = rect.size
                                self.activePanel?.aspectRatio = rect.size
                                self.activePanel?.contentAspectRatio = rect.size
                                
                                // Panelin sol üst köşesini (Top-Left) sabit tutarak yeni boyuta geç
                                var newFrame = currentFrame
                                newFrame.size = newPanelSize
                                newFrame.origin.y = currentFrame.maxY - newPanelSize.height
                                self.activePanel?.setFrame(newFrame, display: true, animate: false)
                                
                                // Etkileşim modu için güncel çerçeveyi de kaydet
                                self.previewView?.originalWindowFrame = rect
                                
                                print(">>> [StreamManager] Orijinal pencere yeniden boyutlandırıldı. Yeni Panel Boyutu: \(newPanelSize)")
                            }
                        }
                    }
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

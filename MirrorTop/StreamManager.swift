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
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
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
        if let currentStream = stream {
            do {
                try await currentStream.stopCapture()
            } catch {
                print("Yayın durdurulurken hata oluştu: \(error)")
            }
        }
        
        self.stream = nil
        self.capturedWindowID = nil
        self.originalWindowInfo = nil
        
        closePanel()
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
            Task { @MainActor in
                self.frameCount += 1
                if self.frameCount == 1 {
                    print(">>> [StreamManager] İLK KARE GELDİ! Ekran yayını başarıyla render ediliyor.")
                }
                self.previewView?.enqueue(sampleBuffer)
                
                // Pencere boyutu değişimini kontrol et (Orijinal pencere boyutlandırılırsa paneli de güncelle)
                guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                      let attachments = attachmentsArray.first else { return }
                
                var newContentRect: CGRect?
                if let rect = attachments[.contentRect] as? CGRect {
                    newContentRect = rect
                } else if let dict = attachments[.contentRect] as? NSDictionary {
                    newContentRect = CGRect(dictionaryRepresentation: dict as CFDictionary)
                }
                
                if let rect = newContentRect {
                    let oldSize = self.originalWindowInfo?.frame.size ?? rect.size
                    // 1 pikselden büyük bir değişim varsa (Floating point hatalarını önlemek için)
                    if abs(oldSize.width - rect.size.width) > 1.0 || abs(oldSize.height - rect.size.height) > 1.0 {
                        
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
        default:
            break
        }
    }
    
    // Yayın sırasında bir hata oluşursa veya yayın manuel dışı durursa
    nonisolated public func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            print("Yayın hatayla durdu: \(error.localizedDescription)")
            await self.stopCapture()
        }
    }
}

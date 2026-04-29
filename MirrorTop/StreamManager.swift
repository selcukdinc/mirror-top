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
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        
        // Sample handler kuyruğu (performans için arka planda işlenecek)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        
        self.stream = newStream
        self.capturedWindowID = windowInfo.cgWindowID
        
        // Paneli hazırlayıp ekranda göster
        setupPanel(for: windowInfo)
        
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
        
        closePanel()
    }
    
    private func setupPanel(for windowInfo: FocusedWindowInfo) {
        if activePanel == nil {
            let panel = FloatingPanel(contentRect: windowInfo.frame)
            let view = CapturePreviewView(frame: NSRect(origin: .zero, size: windowInfo.frame.size))
            view.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(view)
            
            self.previewView = view
            self.activePanel = panel
        }
        
        activePanel?.setFrame(windowInfo.frame, display: true)
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
                // Kareleri Main Thread üzerinde CapturePreviewView'a iletiyoruz.
                self.previewView?.enqueue(sampleBuffer)
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

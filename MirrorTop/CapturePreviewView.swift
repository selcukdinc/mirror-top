import AppKit
import AVFoundation

public final class CapturePreviewView: NSView {
    public let videoLayer = AVSampleBufferDisplayLayer()
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        self.wantsLayer = true
        videoLayer.videoGravity = .resizeAspect
        
        // Performans optimizasyonu için arka planı transparan yapıyoruz.
        videoLayer.isOpaque = false
        videoLayer.backgroundColor = NSColor.clear.cgColor
        self.layer?.addSublayer(videoLayer)
    }
    
    public override func layout() {
        super.layout()
        // Layer boyutunu NSView boyutu ile senkronize tutuyoruz.
        videoLayer.frame = self.bounds
    }
    
    /// ScreenCaptureKit'ten gelen video karelerini render eder.
    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if videoLayer.status == .failed {
            videoLayer.flush()
        }
        videoLayer.enqueue(sampleBuffer)
    }
}

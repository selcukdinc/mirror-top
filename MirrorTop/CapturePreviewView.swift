import AppKit
import AVFoundation

public final class CapturePreviewView: NSView {
    public let videoLayer = AVSampleBufferDisplayLayer()
    
    // Etkileşim modu değişkenleri
    public var interactionMode: Bool = false {
        didSet {
            print(">>> [CapturePreviewView] Interaction Mode: \(interactionMode ? "AÇIK" : "KAPALI")")
            if interactionMode {
                self.layer?.borderWidth = 4.0
                self.layer?.borderColor = NSColor.systemBlue.cgColor
                self.layer?.cornerRadius = 8.0
            } else {
                self.layer?.borderWidth = 0.0
                self.layer?.cornerRadius = 0.0
            }
        }
    }
    public var originalWindowFrame: CGRect = .zero
    public var originalPID: pid_t = 0
    
    public override var acceptsFirstResponder: Bool { return interactionMode }
    
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
        // AVFoundation'da IOSurface destekli buffer'lar için .resizeAspect kullanılmalıdır,
        // aksi takdirde .resize bozulup görüntüyü sol üste sabitler.
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
    
    // MARK: - Input Forwarding (Etkileşim Modu)
    
    public override func mouseDown(with event: NSEvent) {
        if interactionMode && !event.modifierFlags.contains(.command) {
            forwardEvent(event, type: .leftMouseDown)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if interactionMode && !event.modifierFlags.contains(.command) {
            forwardEvent(event, type: .leftMouseUp)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        if interactionMode && !event.modifierFlags.contains(.command) {
            forwardEvent(event, type: .leftMouseDragged)
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    private func forwardEvent(_ event: NSEvent, type: CGEventType) {
        // NSView içindeki lokal koordinat
        let localLocation = self.convert(event.locationInWindow, from: nil)
        
        // Boyut oranını bul (NSView bottom-left odaklıdır)
        let nx = localLocation.x / self.bounds.width
        let ny = 1.0 - (localLocation.y / self.bounds.height) // macOS ekran koordinatları top-left odaklıdır
        
        // Orijinal pencere üzerindeki hedef koordinatı hesapla
        let targetX = originalWindowFrame.minX + (nx * originalWindowFrame.width)
        let targetY = originalWindowFrame.minY + (ny * originalWindowFrame.height)
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // Kendi oluşturduğumuz event'lerin sonsuz döngüye girmesini engellemek için işaretle
        guard let cgEvent = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: targetPoint, mouseButton: .left) else { return }
        
        // Eğer sürükleme (drag) yapıyorsak mouse butonunun basılı olduğunu belirtmeliyiz
        if type == .leftMouseDragged {
            // Sürükleme işlemi için ek ayarlar gerekebilir ama postToPid genelde yeterlidir.
        }
        
        // Event'i doğrudan hedef uygulamanın PID'sine gönder (Fiziksel fareyi hareket ettirmez!)
        if originalPID > 0 {
            cgEvent.postToPid(originalPID)
        } else {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Keyboard Forwarding
    
    public override func keyDown(with event: NSEvent) {
        if interactionMode && originalPID > 0 {
            forwardKeyEvent(event, isDown: true)
        } else {
            super.keyDown(with: event)
        }
    }
    
    public override func keyUp(with event: NSEvent) {
        if interactionMode && originalPID > 0 {
            forwardKeyEvent(event, isDown: false)
        } else {
            super.keyUp(with: event)
        }
    }
    
    private func forwardKeyEvent(_ event: NSEvent, isDown: Bool) {
        guard let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: event.keyCode, keyDown: isDown) else { return }
        // Modifier tuşlarını (Shift, Cmd vb.) koru
        if let originalCG = event.cgEvent {
            cgEvent.flags = originalCG.flags
        }
        cgEvent.postToPid(originalPID)
    }
}

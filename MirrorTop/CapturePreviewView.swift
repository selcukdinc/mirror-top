import AppKit
import AVFoundation
import VideoToolbox
import ApplicationServices

public final class CapturePreviewView: NSView {
    // CALayer + IOSurface yaklaşımı (AVSampleBufferDisplayLayer'ın -12902 hatasını ekarte eder).
    private let videoLayer = CALayer()
    
    /// MirrorRegistry snapshot throttling için kare sayacı.
    private var snapshotFrameCounter: UInt32 = 0
    
    public var interactionMode: Bool = false {
        didSet {
            applyBorderStyle()
        }
    }
    
    /// SettingsManager'daki "Etkileşim modunda mavi çerçeve göster" tercihini yansıtır.
    /// StreamManager.applyAppearance() çağrısıyla güncellenir.
    public var showInteractionBorder: Bool = true {
        didSet {
            applyBorderStyle()
        }
    }
    
    private func applyBorderStyle() {
        if interactionMode && showInteractionBorder {
            self.layer?.borderWidth = 4.0
            self.layer?.borderColor = NSColor.systemBlue.cgColor
            self.layer?.cornerRadius = 8.0
        } else {
            self.layer?.borderWidth = 0.0
            self.layer?.cornerRadius = 0.0
        }
    }
    
    /// Kaynak pencerenin ekran üzerindeki son bilinen frame'i (top-left origin).
    /// AX ile her tık öncesi tazelenir.
    public var originalWindowFrame: CGRect = .zero
    public var originalPID: pid_t = 0
    /// AX üzerinden anlık konum okuyabilmek için stream başlangıcında saklanır.
    public var sourceAXWindow: AXUIElement?
    
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
        // Buffer artık kaynak pencereyle birebir aynı boyutta (StreamManager config'i canlı günceller),
        // bu yüzden .resize ile layer'ı tam doldurabiliriz. Letterbox YOK.
        videoLayer.contentsGravity = .resize
        videoLayer.masksToBounds = true
        videoLayer.isOpaque = false
        videoLayer.backgroundColor = NSColor.clear.cgColor
        self.layer?.addSublayer(videoLayer)
        self.layer?.masksToBounds = true
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = self.bounds
        CATransaction.commit()
    }
    
    /// ScreenCaptureKit'ten gelen kareleri render eder.
    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let image = cgImage else { return }
        // Dock-mode için her ~30 karede bir registry snapshot güncelle (60fps → ~2/sn).
        snapshotFrameCounter &+= 1
        if snapshotFrameCounter % 30 == 0 {
            let imageCopy = image
            DispatchQueue.main.async {
                MirrorRegistry.shared.updateActiveSnapshot(image: imageCopy)
            }
        }
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.videoLayer.contents = image
            CATransaction.commit()
        }
    }
    
    // MARK: - Input Forwarding (Etkileşim Modu)
    //
    // STRATEJİ:
    //  • mouseDown: hiçbir event POST ETME, sadece state kaydet (downLocation, time).
    //  • mouseDragged: ilk drag'de threshold (3px) aşıldıysa drag mode'a gir, postToPid ile
    //    .leftMouseDown gönder, sonra her drag için .leftMouseDragged. postToPid cursor'ı
    //    warp etmediği için drag akıcı, mouseUp panele gelir, ekran sallanmaz.
    //  • mouseUp:
    //      - drag mode'daysak → .leftMouseUp postToPid.
    //      - drag olmadıysa (saf click) → cghidEventTap ile atomik down+up gönder, sonra
    //        cursor'ı orijinal yerine geri warp et. Bu yöntem AppKit toolbar/NSPopUpButton
    //        gibi kontrolleri tetikler (active-app şartını aşar) ve cursor warp tek
    //        seferlik/anlık olduğu için kullanıcı görsel olarak sallanma görmez.
    //  • Bu mimaride NSView mouseUp HER ZAMAN gelir (down post edilmediği veya postToPid
    //    kullanıldığı için cursor panel'den çıkmaz), yani tıklama hiçbir zaman yarım kalmaz.
    
    private var mouseDownLocation: NSPoint = .zero
    private var isDragging: Bool = false
    private static let dragThreshold: CGFloat = 3.0
    
    public override func mouseDown(with event: NSEvent) {
        if interactionMode {
            // Cmd basılıyken paneli sürükle (event'i yönlendirme).
            if event.modifierFlags.contains(.command) {
                self.window?.performDrag(with: event)
                return
            }
            // SADECE state kaydet — POST ETME. Drag mı click mi olduğunu sonra anlayacağız.
            mouseDownLocation = event.locationInWindow
            isDragging = false
        } else {
            super.mouseDown(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if interactionMode && !event.modifierFlags.contains(.command) {
            if isDragging {
                // Drag bitti → up'ı postToPid ile gönder (cursor warp yok).
                forwardMouse(event, type: .leftMouseUp, button: .left, viaCghid: false)
                isDragging = false
            } else {
                // SAF CLICK → postToPid ile atomik down+up; cursor warp YOK.
                // Kullanıcı tercihi: hiçbir koşulda fare hedef pencereye ışınlanmasın.
                forwardClickPost(event, button: .left)
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        if interactionMode && !event.modifierFlags.contains(.command) {
            if !isDragging {
                let dx = event.locationInWindow.x - mouseDownLocation.x
                let dy = event.locationInWindow.y - mouseDownLocation.y
                guard (dx * dx + dy * dy) > (Self.dragThreshold * Self.dragThreshold) else {
                    return // henüz drag sayılmaz
                }
                isDragging = true
                // İlk drag → önce mouseDown'ı postToPid ile bildir (cursor warp yok).
                forwardMouse(event, type: .leftMouseDown, button: .left, viaCghid: false)
            }
            forwardMouse(event, type: .leftMouseDragged, button: .left, viaCghid: false)
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        if interactionMode {
            // Sağ tık: postToPid ile cursor warp etmeden gönder.
            forwardClickPost(event, button: .right)
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        if !interactionMode { super.rightMouseUp(with: event) }
        // Atomik click rightMouseDown'da gönderildi, burada bir şey yapmıyoruz.
    }
    
    public override func scrollWheel(with event: NSEvent) {
        if interactionMode { forwardScroll(event) }
        else { super.scrollWheel(with: event) }
    }
    
    private static let eventSource: CGEventSource? = CGEventSource(stateID: .combinedSessionState)
    
    /// AX üzerinden kaynak pencerenin GÜNCEL ekran konumunu/boyutunu çek; başarısızsa cache'i kullan.
    private func currentWindowFrame() -> CGRect {
        guard let axWin = sourceAXWindow else { return originalWindowFrame }
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var pos = CGPoint.zero
        var size = CGSize.zero
        if AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef) == .success,
           let v = posRef as! AXValue? {
            AXValueGetValue(v, .cgPoint, &pos)
        } else {
            return originalWindowFrame
        }
        if AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let v = sizeRef as! AXValue? {
            AXValueGetValue(v, .cgSize, &size)
        } else {
            return originalWindowFrame
        }
        let frame = CGRect(origin: pos, size: size)
        DispatchQueue.main.async { [weak self] in self?.originalWindowFrame = frame }
        return frame
    }
    
    /// View-local koordinatı kaynak pencerenin ekran (flipped, top-left) koordinatına çevirir.
    private func screenTarget(for event: NSEvent) -> CGPoint? {
        let localLocation = self.convert(event.locationInWindow, from: nil)
        let viewSize = self.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let winFrame = currentWindowFrame()
        guard winFrame.width > 0, winFrame.height > 0 else { return nil }
        let nx = max(0, min(1, localLocation.x / viewSize.width))
        // NSView default unflipped (origin bottom-left); ekran/AX flipped (origin top-left).
        let ny = max(0, min(1, 1.0 - (localLocation.y / viewSize.height)))
        return CGPoint(x: winFrame.minX + nx * winFrame.width,
                       y: winFrame.minY + ny * winFrame.height)
    }
    
    /// Saf click: cursor'u HİÇBİR ŞEKİLDE warp ETMEDEN postToPid ile down+up gönderir.
    /// Trade-off: NSPopUpButton/NSToolbar gibi global event tap bekleyen kontroller ile
    /// uyumluluk azalabilir. Kullanıcı tercihi gereği fare hareket etmemelidir.
    private func forwardClickPost(_ event: NSEvent, button: CGMouseButton) {
        guard originalPID > 0, let target = screenTarget(for: event) else { return }
        let downType: CGEventType = (button == .right) ? .rightMouseDown : .leftMouseDown
        let upType:   CGEventType = (button == .right) ? .rightMouseUp   : .leftMouseUp
        let clickCount = Int64(max(event.clickCount, 1))
        
        if let down = CGEvent(mouseEventSource: Self.eventSource,
                              mouseType: downType,
                              mouseCursorPosition: target,
                              mouseButton: button) {
            down.setIntegerValueField(.mouseEventClickState, value: clickCount)
            down.postToPid(originalPID)
        }
        if let up = CGEvent(mouseEventSource: Self.eventSource,
                            mouseType: upType,
                            mouseCursorPosition: target,
                            mouseButton: button) {
            up.setIntegerValueField(.mouseEventClickState, value: clickCount)
            up.postToPid(originalPID)
        }
    }
    
    /// Saf click: cghidEventTap ile atomik mouseDown+mouseUp, sonra cursor'ı orijinal
    /// (kullanıcı parmağının fiziksel) konumuna geri warp et. Active-app şartını aşar.
    private func forwardClickAtomic(_ event: NSEvent, button: CGMouseButton) {
        guard originalPID > 0, let target = screenTarget(for: event) else { return }
        let downType: CGEventType = (button == .right) ? .rightMouseDown : .leftMouseDown
        let upType:   CGEventType = (button == .right) ? .rightMouseUp   : .leftMouseUp
        
        // Cursor'ı geri taşımak için fiziksel imleç konumunu sakla.
        // NSEvent.mouseLocation: bottom-left referanslı (NSScreen koordinatları).
        let cursorBeforeUnflipped = NSEvent.mouseLocation
        let mainHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
        let cursorBeforeFlipped = CGPoint(x: cursorBeforeUnflipped.x,
                                          y: mainHeight - cursorBeforeUnflipped.y)
        
        // Hover state için (NSPopUpButton, NSToolbar tracking) önce mouseMoved.
        if let move = CGEvent(mouseEventSource: Self.eventSource,
                              mouseType: .mouseMoved,
                              mouseCursorPosition: target,
                              mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
        
        let clickCount = Int64(max(event.clickCount, 1))
        
        if let down = CGEvent(mouseEventSource: Self.eventSource,
                              mouseType: downType,
                              mouseCursorPosition: target,
                              mouseButton: button) {
            down.setIntegerValueField(.mouseEventClickState, value: clickCount)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: Self.eventSource,
                            mouseType: upType,
                            mouseCursorPosition: target,
                            mouseButton: button) {
            up.setIntegerValueField(.mouseEventClickState, value: clickCount)
            up.post(tap: .cghidEventTap)
        }
        
        // Cursor'ı kullanıcının fiziksel konumuna geri al (warp süresi anlık → flicker minimal).
        CGWarpMouseCursorPosition(cursorBeforeFlipped)
    }
    
    /// Drag akışında kullanılır: postToPid → cursor warp etmez, sallanma yok.
    /// `viaCghid = true` parametresi gelirse atomik click yerine tek event cghidEventTap ile gider
    /// (şu an sadece postToPid yolu kullanılıyor; parametre gelecek esneklik için).
    private func forwardMouse(_ event: NSEvent, type: CGEventType, button: CGMouseButton, viaCghid: Bool) {
        guard originalPID > 0, let target = screenTarget(for: event) else { return }
        guard let cgEvent = CGEvent(mouseEventSource: Self.eventSource,
                                     mouseType: type,
                                     mouseCursorPosition: target,
                                     mouseButton: button) else { return }
        cgEvent.setIntegerValueField(.mouseEventClickState, value: Int64(max(event.clickCount, 1)))
        if viaCghid {
            cgEvent.post(tap: .cghidEventTap)
        } else {
            cgEvent.postToPid(originalPID)
        }
    }
    
    private func forwardScroll(_ event: NSEvent) {
        guard originalPID > 0 else { return }
        // Scroll'da cursor warp olmaması için postToPid kullanıyoruz.
        // Trade-off: hover-only scroll trackerlar (örn. macOS sistem genelinde scroll
        // yakalayan bazı görünümler) bu event'i görmeyebilir. Kullanıcı tercihi gereği.
        guard let target = screenTargetForScroll(event) else { return }
        let dy = Int32(event.scrollingDeltaY)
        let dx = Int32(event.scrollingDeltaX)
        guard let cgEvent = CGEvent(scrollWheelEvent2Source: Self.eventSource,
                                    units: .pixel,
                                    wheelCount: 2,
                                    wheel1: dy,
                                    wheel2: dx,
                                    wheel3: 0) else { return }
        cgEvent.location = target
        cgEvent.postToPid(originalPID)
    }
    
    private func screenTargetForScroll(_ event: NSEvent) -> CGPoint? {
        let localLocation = self.convert(event.locationInWindow, from: nil)
        let viewSize = self.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let winFrame = currentWindowFrame()
        guard winFrame.width > 0, winFrame.height > 0 else { return nil }
        let nx = max(0, min(1, localLocation.x / viewSize.width))
        let ny = max(0, min(1, 1.0 - (localLocation.y / viewSize.height)))
        return CGPoint(x: winFrame.minX + nx * winFrame.width,
                       y: winFrame.minY + ny * winFrame.height)
    }
    
    // MARK: - Keyboard Forwarding
    
    public override func keyDown(with event: NSEvent) {
        if interactionMode && originalPID > 0 { forwardKeyEvent(event, isDown: true) }
        else { super.keyDown(with: event) }
    }
    
    public override func keyUp(with event: NSEvent) {
        if interactionMode && originalPID > 0 { forwardKeyEvent(event, isDown: false) }
        else { super.keyUp(with: event) }
    }
    
    private func forwardKeyEvent(_ event: NSEvent, isDown: Bool) {
        guard let cgEvent = CGEvent(keyboardEventSource: Self.eventSource,
                                     virtualKey: event.keyCode,
                                     keyDown: isDown) else { return }
        if let originalCG = event.cgEvent {
            cgEvent.flags = originalCG.flags
        }
        cgEvent.postToPid(originalPID)
    }
}

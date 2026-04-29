import AppKit

public final class FloatingPanel: NSPanel {
    public init(contentRect: NSRect) {
        // macOS'te .borderless pencereler kenarlardan yeniden boyutlandırılamaz.
        // Bu yüzden .titled kullanıp başlık çubuğunu tamamen gizliyoruz (hacksiz native resize desteği için).
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .nonactivatingPanel, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        
        self.level = .floating // Always on Top
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle] // Tüm space'lerde görünür
        self.backgroundColor = .clear // Şeffaf arka plan
        self.isOpaque = false
        self.hasShadow = true // Gölgeli
        
        // Başlık çubuğunu görünmez yap
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        // Trafik lambası (kapat, küçült, büyüt) butonlarını gizle
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Panelin varsayılan davranışı (İzleme Modu - View Only)
        self.ignoresMouseEvents = true // Tıklamalar içinden geçer, alttaki uygulamaya gider
        self.isMovableByWindowBackground = true // İçinden tutulup taşınabilsin (Interaction mode'da)
        
        setupMenu()
    }
    
    // Sağ tık menüsü kurulumu
    private func setupMenu() {
        let menu = NSMenu(title: "MirrorTop")
        let toggleItem = NSMenuItem(title: "Etkileşim Modunu Aç/Kapat", action: #selector(toggleMode), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.contentView?.menu = menu
    }
    
    @objc private func toggleMode() {
        // StreamManager'ı referans alarak modu değiştir
        StreamManager.shared.toggleInteractionMode()
    }
    
    public override var canBecomeKey: Bool { return interactionMode }
    public override var canBecomeMain: Bool { return interactionMode }
    
    public var interactionMode: Bool = false {
        didSet {
            // Etkileşim modu açıksa fareyi yakala, kapalıysa alttaki uygulamaya (ör. IDE'ye) tıklamayı geçir
            self.ignoresMouseEvents = !interactionMode
            
            if interactionMode {
                // Etkileşim modundayken klavye girişlerini (focus) alabilmesi için
                self.makeKeyAndOrderFront(nil)
            }
        }
    }
}

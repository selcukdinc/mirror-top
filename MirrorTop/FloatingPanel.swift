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
        
        // Panelin fare ile tutulup taşınabilmesi ve boyutlandırılabilmesi için:
        self.ignoresMouseEvents = false // Fare tıklamalarını algılasın
        self.isMovableByWindowBackground = true // İçinden tutulup taşınabilsin
    }
}

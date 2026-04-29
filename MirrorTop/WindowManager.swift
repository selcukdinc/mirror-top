import Foundation
import ApplicationServices
import AppKit
import ScreenCaptureKit

public struct FocusedWindowInfo: Sendable {
    public let cgWindowID: CGWindowID
    public let title: String
    public var frame: CGRect
    public let pid: pid_t
    public let appName: String
}

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()
    
    private init() {}
    
    /// Şu an odaklanılmış olan pencerenin CGWindowID, başlık ve konum bilgilerini yakalar.
    /// async/await yapısına uygun olarak arka planda ScreenCaptureKit kullanarak pencereyi bulur.
    public func getFocusedWindow() async throws -> FocusedWindowInfo? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print(">>> [WindowManager] Hata: NSWorkspace.shared.frontmostApplication bulunamadı.")
            return nil
        }
        let pid = frontmostApp.processIdentifier
        
        // KRİTİK: Etkileşim modunda kullanıcı panele tıklayınca MirrorTop önplana geçiyor.
        // Bu sırada Cmd+Opt+T'ye basılırsa kendi FloatingPanel'imizin CGWindowID'sini yakalardık
        // ve sonsuz feedback loop'una düşerdik (kendi mirror'ımızı mirror etmek -> GPU/RAM patlaması -> crash).
        let ourPID = ProcessInfo.processInfo.processIdentifier
        if pid == ourPID {
            print(">>> [WindowManager] Odaktaki uygulama MirrorTop'un kendisi. Recursive capture engellendi.")
            return nil
        }
        
        print(">>> [WindowManager] Odaktaki uygulama: \(frontmostApp.localizedName ?? "Bilinmiyor") (PID: \(pid))")
        
        let appElement = AXUIElementCreateApplication(pid)
        
        var focusedWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
        
        guard result == .success, let windowElement = focusedWindowRef as! AXUIElement? else {
            print(">>> [WindowManager] Hata: kAXFocusedWindowAttribute alınamadı. AXError kodu: \(result.rawValue)")
            return nil
        }
        
        // Pencere Başlığını (Title) AX ile Al
        var titleRef: CFTypeRef?
        var title = ""
        if AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef) == .success,
           let titleString = titleRef as? String {
            title = titleString
        }
        
        // Pencere Konumunu (Position) AX ile Al
        var positionRef: CFTypeRef?
        var position = CGPoint.zero
        if AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionRef) == .success {
            let val = positionRef as! AXValue
            AXValueGetValue(val, .cgPoint, &position)
        }
        
        // Pencere Boyutunu (Size) AX ile Al
        var sizeRef: CFTypeRef?
        var size = CGSize.zero
        if AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success {
            let val = sizeRef as! AXValue
            AXValueGetValue(val, .cgSize, &size)
        }
        
        let axFrame = CGRect(origin: position, size: size)
        print(">>> [WindowManager] AX Penceresi bulundu. Başlık: '\(title)', Frame: \(axFrame)")
        
        var cgWindowID: CGWindowID? = nil
        
        // 1. Yöntem: AXCGWindowIdentifier (Bazı durumlarda çalışmayabilir ancak en hızlı yoldur)
        var windowIDRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(windowElement, "AXCGWindowIdentifier" as CFString, &windowIDRef) == .success,
           let number = windowIDRef as? NSNumber {
            cgWindowID = CGWindowID(number.uint32Value)
            print(">>> [WindowManager] AXCGWindowIdentifier ile ID bulundu: \(cgWindowID!)")
        } else {
            print(">>> [WindowManager] AXCGWindowIdentifier ile ID bulunamadı. ScreenCaptureKit fallback deneniyor...")
        }
        
        // 2. Yöntem: ScreenCaptureKit ile eşleştirme (Modern ve Güvenilir Yöntem)
        if cgWindowID == nil {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print(">>> [WindowManager] ScreenCaptureKit'ten \(shareableContent.windows.count) adet pencere çekildi.")
            
            // Ekran kaydı izni yoksa, shareableContent.windows diğer uygulamaların pencerelerini GÖSTERMEZ.
            if shareableContent.windows.isEmpty || !shareableContent.windows.contains(where: { $0.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier }) {
                print(">>> [WindowManager] UYARI: SCShareableContent sadece bizim uygulamanın pencerelerini görüyor olabilir. Ekran Kaydı izniniz (Screen Recording permission) eksik olabilir!")
            }
            
            // PID'e ve Başlığa veya Frame'e göre eşleşen pencereyi bul
            if let scWindow = shareableContent.windows.first(where: { 
                $0.owningApplication?.processID == pid && 
                ($0.title == title || $0.frame == axFrame)
            }) {
                cgWindowID = scWindow.windowID
                print(">>> [WindowManager] ScreenCaptureKit ile ID eşleştirildi: \(cgWindowID!)")
            } else {
                print(">>> [WindowManager] Hata: SCShareableContent içinde PID: \(pid) ve Başlık: '\(title)' / Frame: \(axFrame) eşleşen pencere bulunamadı.")
            }
        }
        
        guard let finalWindowID = cgWindowID else {
            print(">>> [WindowManager] Odaklanan pencereye ait CGWindowID hiçbir yöntemle çözümlenemedi.")
            return nil
        }
        
        return FocusedWindowInfo(
            cgWindowID: finalWindowID,
            title: title,
            frame: axFrame,
            pid: pid,
            appName: frontmostApp.localizedName ?? "Bilinmeyen"
        )
    }
}

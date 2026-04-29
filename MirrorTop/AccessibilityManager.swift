import Foundation
import ApplicationServices
import AppKit

@MainActor
public final class AccessibilityManager {
    public static let shared = AccessibilityManager()
    
    private init() {}
    
    /// Sistemde uygulamanın Accessibility (Erişilebilirlik) izinlerine sahip olup olmadığını kontrol eder.
    public func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// İzinleri kontrol eder ve eğer izin yoksa kullanıcıyı Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik menüsüne yönlendirir.
    public func checkAndPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Erişilebilirlik izni eksik. Sistem Ayarları açılıyor...")
            
            // Eğer macOS kendi prompt'unu göstermediyse (Xcode derlemelerinde sıkça olur),
            // Sistem Ayarları'ndaki Gizlilik ve Güvenlik > Erişilebilirlik sekmesini manuel açalım.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            
            // Kullanıcının uygulamayı listeye kolayca sürükleyebilmesi için Finder'da uygulamanın yerini açalım.
            let appURL = Bundle.main.bundleURL
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
            
            print(">>> [DEBUG] Finder açıldı. Lütfen seçili olan 'MirrorTop' uygulamasını Erişilebilirlik listesine SÜRÜKLE BIRAK yöntemiyle ekleyin.")
        }
        
        return accessEnabled
    }
}

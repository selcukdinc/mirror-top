import Foundation
import AppKit

/// TCC (Transparency, Consent, Control) izinlerini sıfırlamak için yardımcı.
/// Xcode'dan her yeni build aldığınızda imza özetinin (designated requirement) farklı olması
/// macOS'in eski izin kayıtlarını "stale" olarak görmesine yol açabilir; bu durumda kullanıcı
/// sistem ayarlarında MirrorTop'u silip eklemek zorunda kalır.
///
/// Bu yardımcı `tccutil reset All <bundleID>` komutunu çalıştırır ve bunun ardından
/// kullanıcıyı doğru sistem ayarları paneline yönlendirir.
public enum PermissionResetHelper {
    
    /// MirrorTop için TCC kayıtlarını sıfırlar. Bundle ID otomatik olarak okunur.
    @MainActor
    public static func resetAllPermissions() {
        let bundleID = Bundle.main.bundleIdentifier ?? "tr.com.devloop.MirrorTop"
        runTccutilReset(bundleID: bundleID)
        
        // Kısa bir gecikme sonrası izin manager'ları yenile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            PermissionsManager.shared.refresh()
        }
    }
    
    @discardableResult
    private static func runTccutilReset(bundleID: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/tccutil"
        process.arguments = ["reset", "All", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print(">>> [PermissionResetHelper] tccutil hatası: \(error)")
            return false
        }
    }
}

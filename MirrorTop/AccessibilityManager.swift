import Foundation
import ApplicationServices
import AppKit

/// Geriye dönük uyumluluk için bırakıldı. Yeni kod `PermissionsManager`'ı kullanmalı.
/// İzin akışı artık `OnboardingView` üzerinden modern bir SwiftUI deneyimiyle gösteriliyor;
/// burada Finder pop-up veya prompt açma gibi rahatsız edici davranışlar yok.
@MainActor
public final class AccessibilityManager {
    public static let shared = AccessibilityManager()
    
    private init() {}
    
    /// Sistemde uygulamanın Accessibility (Erişilebilirlik) izinlerine sahip olup olmadığını kontrol eder.
    public func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
}


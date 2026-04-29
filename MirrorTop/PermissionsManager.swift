import SwiftUI
import ApplicationServices
import CoreGraphics
import AppKit

/// İki izni de canlı izleyen merkezi gözlemlenebilir model.
/// Onboarding penceresi bu modeli izleyerek izin durumu değiştiğinde anında UI'ı günceller.
@MainActor
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    
    @Published public private(set) var accessibilityGranted: Bool = false
    @Published public private(set) var screenRecordingGranted: Bool = false
    
    private var timer: Timer?
    
    public var allGranted: Bool {
        accessibilityGranted && screenRecordingGranted
    }
    
    private init() {
        refresh()
    }
    
    /// Mevcut durumu sistemden anlık çeker.
    public func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
    
    /// Onboarding açıkken her saniye izin durumunu kontrol eder; kullanıcı
    /// Sistem Ayarları'nda izin verdiği anda UI canlı güncellenir.
    public func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
    
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Erişilebilirlik iznini ister. macOS sistem prompt'unu gösterir; kullanıcı reddederse ayarları açabiliriz.
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Prompt zaten gösterildi, sadece ayar paneline yönlendir.
        openAccessibilitySettings()
    }
    
    /// Ekran kaydı iznini ister. İlk çağrıda macOS sistem prompt'unu gösterir.
    public func requestScreenRecording() {
        // İlk çağrıda sistem prompt'u gösterir; sonraki çağrılarda hiçbir şey yapmaz.
        CGRequestScreenCaptureAccess()
        // Yine de ayar panelini açıyoruz; izin reddedilmişse kullanıcı oradan açabilir.
        openScreenRecordingSettings()
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

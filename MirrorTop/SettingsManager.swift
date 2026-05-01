import Foundation
import SwiftUI
import Combine
import AppKit

public extension Notification.Name {
    /// Görünüm ayarları (opacity, ghostMode, border) değiştiğinde post edilir.
    static let mtAppearanceChanged = Notification.Name("mt.appearanceChanged")
}

/// Kullanıcı tercihlerini saklayan merkezi yönetici (UserDefaults).
/// Dil seçimi, otomatik güncelleme tercihi gibi ayarları tutar.
@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private enum Keys {
        static let language = "mt.settings.language"
        static let autoUpdateCheck = "mt.settings.autoUpdateCheck"
        static let lastUpdateCheck = "mt.settings.lastUpdateCheck"
        static let captureShortcut = "mt.settings.captureShortcut"
        static let interactionShortcut = "mt.settings.interactionShortcut"
        // Görünüm
        static let opacity = "mt.settings.opacity"
        static let ghostMode = "mt.settings.ghostMode"
        static let ghostOpacity = "mt.settings.ghostOpacity"
        static let showInteractionBorder = "mt.settings.showInteractionBorder"
        // Davranış
        static let snapToCorners = "mt.settings.snapToCorners"
        static let rememberPositionPerWindow = "mt.settings.rememberPositionPerWindow"
        // Per-window pozisyon kaydı (UserDefaults: dictionary frame string)
        static func windowFrameKey(bundleID: String, titleHash: String) -> String {
            return "mt.layout.window.\(bundleID).\(titleHash)"
        }
    }
    
    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        }
    }
    
    /// Açılışta güncelleme kontrolü yapılsın mı? **Varsayılan: kapalı.**
    @Published public var autoUpdateCheck: Bool {
        didSet { UserDefaults.standard.set(autoUpdateCheck, forKey: Keys.autoUpdateCheck) }
    }
    
    /// Son güncelleme kontrolü zamanı.
    @Published public var lastUpdateCheck: Date? {
        didSet {
            if let d = lastUpdateCheck {
                UserDefaults.standard.set(d, forKey: Keys.lastUpdateCheck)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastUpdateCheck)
            }
        }
    }
    
    /// Yansıtmayı aç/kapat kısayolu.
    @Published public var captureShortcut: Shortcut {
        didSet {
            Self.saveShortcut(captureShortcut, forKey: Keys.captureShortcut)
            GlobalHotkeyManager.shared.reloadShortcuts()
        }
    }
    
    /// Etkileşim modu kısayolu.
    @Published public var interactionShortcut: Shortcut {
        didSet {
            Self.saveShortcut(interactionShortcut, forKey: Keys.interactionShortcut)
            GlobalHotkeyManager.shared.reloadShortcuts()
        }
    }
    
    // MARK: - Görünüm
    
    /// PiP panelinin genel opaklığı (0.2 — 1.0). Varsayılan 1.0.
    @Published public var opacity: Double {
        didSet {
            UserDefaults.standard.set(opacity, forKey: Keys.opacity)
            NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
        }
    }
    
    /// Hayalet modu: başka uygulama önplandayken PiP daha şeffaflaşır.
    @Published public var ghostMode: Bool {
        didSet {
            UserDefaults.standard.set(ghostMode, forKey: Keys.ghostMode)
            NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
        }
    }
    
    /// Hayalet modunda kullanılan opaklık (0.1 — 0.9). Varsayılan 0.4.
    @Published public var ghostOpacity: Double {
        didSet {
            UserDefaults.standard.set(ghostOpacity, forKey: Keys.ghostOpacity)
            NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
        }
    }
    
    /// Etkileşim modunda mavi çerçeve gösterilsin mi?
    @Published public var showInteractionBorder: Bool {
        didSet {
            UserDefaults.standard.set(showInteractionBorder, forKey: Keys.showInteractionBorder)
            NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
        }
    }
    
    // MARK: - Davranış
    
    /// Sürüklerken ekran köşelerine yapışsın mı?
    @Published public var snapToCorners: Bool {
        didSet { UserDefaults.standard.set(snapToCorners, forKey: Keys.snapToCorners) }
    }
    
    /// Aynı pencere için pozisyon hatırlansın mı?
    @Published public var rememberPositionPerWindow: Bool {
        didSet { UserDefaults.standard.set(rememberPositionPerWindow, forKey: Keys.rememberPositionPerWindow) }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: raw) {
            self.language = lang
        } else {
            self.language = .system
        }
        self.autoUpdateCheck = defaults.object(forKey: Keys.autoUpdateCheck) as? Bool ?? false
        self.lastUpdateCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date
        self.captureShortcut     = Self.loadShortcut(forKey: Keys.captureShortcut)     ?? .defaultCapture
        self.interactionShortcut = Self.loadShortcut(forKey: Keys.interactionShortcut) ?? .defaultInteraction
        // Görünüm
        self.opacity              = (defaults.object(forKey: Keys.opacity) as? Double) ?? 1.0
        self.ghostMode            = defaults.object(forKey: Keys.ghostMode) as? Bool ?? false
        self.ghostOpacity         = (defaults.object(forKey: Keys.ghostOpacity) as? Double) ?? 0.4
        self.showInteractionBorder = defaults.object(forKey: Keys.showInteractionBorder) as? Bool ?? true
        // Davranış
        self.snapToCorners            = defaults.object(forKey: Keys.snapToCorners) as? Bool ?? true
        self.rememberPositionPerWindow = defaults.object(forKey: Keys.rememberPositionPerWindow) as? Bool ?? true
    }
    
    /// Kısayolları varsayılana sıfırla.
    public func resetShortcutsToDefaults() {
        captureShortcut = .defaultCapture
        interactionShortcut = .defaultInteraction
    }
    
    // MARK: - Per-window pozisyon persistance
    
    /// Verilen kaynak pencere için kayıtlı frame'i döndürür.
    public func savedFrame(forBundleID bundleID: String, titleHash: String) -> NSRect? {
        let key = Keys.windowFrameKey(bundleID: bundleID, titleHash: titleHash)
        guard let str = UserDefaults.standard.string(forKey: key) else { return nil }
        let r = NSRectFromString(str)
        return r == .zero ? nil : r
    }
    
    /// Frame'i kaydeder. (rememberPositionPerWindow kapalıysa no-op.)
    public func saveFrame(_ frame: NSRect, forBundleID bundleID: String, titleHash: String) {
        guard rememberPositionPerWindow else { return }
        let key = Keys.windowFrameKey(bundleID: bundleID, titleHash: titleHash)
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }
    
    // MARK: - Helpers
    
    private static func loadShortcut(forKey key: String) -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }
    
    private static func saveShortcut(_ shortcut: Shortcut, forKey key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

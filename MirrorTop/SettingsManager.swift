import Foundation
import SwiftUI
import Combine
import AppKit

public extension Notification.Name {
    /// Görünüm ayarları (opacity, ghostMode, border) değiştiğinde post edilir.
    static let mtAppearanceChanged = Notification.Name("mt.appearanceChanged")
    /// Tema değiştiğinde post edilir.
    static let mtThemeChanged = Notification.Name("mt.themeChanged")
}

// MARK: - Theme

/// Uygulama teması. 4 seçenek: Sistem-takibi (Light/Dark) yerine kullanıcıya
/// 4 sabit tema sunuyoruz: classic (light), midnight (dark), ocean, sunset.
public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case classic   // Aydınlık (Klasik)
    case midnight  // Karanlık (Gece)
    case ocean     // Özel: Okyanus
    case sunset    // Özel: Gün Batımı
    
    public var id: String { rawValue }
    
    @MainActor
    public var displayName: String {
        switch self {
        case .classic:  return L10n.tr("Klasik (Aydınlık)", "Classic (Light)")
        case .midnight: return L10n.tr("Gece (Karanlık)",   "Midnight (Dark)")
        case .ocean:    return L10n.tr("Okyanus",           "Ocean")
        case .sunset:   return L10n.tr("Gün Batımı",        "Sunset")
        }
    }
    
    /// SwiftUI `preferredColorScheme` için tercih edilen şema.
    public var colorScheme: ColorScheme? {
        switch self {
        case .classic, .ocean:     return .light
        case .midnight, .sunset:   return .dark
        }
    }
    
    /// Tema accent rengi (Color).
    public var accent: Color {
        switch self {
        case .classic:  return .accentColor
        case .midnight: return Color(red: 0.55, green: 0.65, blue: 1.0)
        case .ocean:    return Color(red: 0.10, green: 0.55, blue: 0.85)
        case .sunset:   return Color(red: 0.95, green: 0.45, blue: 0.30)
        }
    }
    
    /// Sembol ikonu — tema seçici grid'inde gösterim için.
    public var symbol: String {
        switch self {
        case .classic:  return "sun.max.fill"
        case .midnight: return "moon.stars.fill"
        case .ocean:    return "drop.fill"
        case .sunset:   return "sunset.fill"
        }
    }
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
        // Tema
        static let theme = "mt.settings.theme"
        // Davranış
        static let snapToCorners = "mt.settings.snapToCorners"
        static let rememberPositionPerWindow = "mt.settings.rememberPositionPerWindow"
        // Per-window pozisyon kaydı (UserDefaults: dictionary frame string)
        static func windowFrameKey(bundleID: String, titleHash: String) -> String {
            return "mt.layout.window.\(bundleID).\(titleHash)"
        }
        /// Per-window opaklık override prefix'i (silmek için)
        static let perWindowOpacityPrefix = "mt.opacity.window."
        static func windowOpacityKey(bundleID: String, titleHash: String) -> String {
            return "\(perWindowOpacityPrefix)\(bundleID).\(titleHash)"
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
    
    /// Uygulama teması (4 sabit tema). Değiştiğinde pencereler `preferredColorScheme`'i takip eder.
    @Published public var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
            NotificationCenter.default.post(name: .mtThemeChanged, object: nil)
        }
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
        // Tema
        if let raw = defaults.string(forKey: Keys.theme), let t = AppTheme(rawValue: raw) {
            self.theme = t
        } else {
            self.theme = .classic
        }
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
    
    // MARK: - Per-window opacity override
    
    /// Verilen pencere için kayıtlı opaklık override'ı (yoksa nil → genel opacity kullanılır).
    public func windowOpacity(forBundleID bundleID: String, titleHash: String) -> Double? {
        let key = Keys.windowOpacityKey(bundleID: bundleID, titleHash: titleHash)
        guard let v = UserDefaults.standard.object(forKey: key) as? Double else { return nil }
        return v
    }
    
    public func saveWindowOpacity(_ opacity: Double, forBundleID bundleID: String, titleHash: String) {
        let key = Keys.windowOpacityKey(bundleID: bundleID, titleHash: titleHash)
        UserDefaults.standard.set(opacity, forKey: key)
        NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
    }
    
    public func clearWindowOpacity(forBundleID bundleID: String, titleHash: String) {
        let key = Keys.windowOpacityKey(bundleID: bundleID, titleHash: titleHash)
        UserDefaults.standard.removeObject(forKey: key)
        NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
    }
    
    /// Tüm per-window opaklık override'larını temizler. Master opacity ayarını
    /// "tüm pencerelere uygula" amaçlı kullanır.
    public func clearAllWindowOpacityOverrides() {
        let defaults = UserDefaults.standard
        let prefix = Keys.perWindowOpacityPrefix
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        NotificationCenter.default.post(name: .mtAppearanceChanged, object: nil)
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

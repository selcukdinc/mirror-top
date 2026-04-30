import Foundation
import SwiftUI
import Combine

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
    }
    
    /// Kısayolları varsayılana sıfırla.
    public func resetShortcutsToDefaults() {
        captureShortcut = .defaultCapture
        interactionShortcut = .defaultInteraction
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

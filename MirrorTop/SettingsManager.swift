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
    }
    
    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            // Dil değiştiğinde tüm SwiftUI view'ları güncellensin diye objectWillChange yayını otomatik.
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
    
    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: raw) {
            self.language = lang
        } else {
            self.language = .system
        }
        // Açılışta güncelleme kontrolü VARSAYILAN OLARAK KAPALI.
        self.autoUpdateCheck = defaults.object(forKey: Keys.autoUpdateCheck) as? Bool ?? false
        self.lastUpdateCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date
    }
}

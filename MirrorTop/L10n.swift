import Foundation
import SwiftUI
import Combine

// MARK: - Desteklenen Diller / Supported Languages

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case turkish = "tr"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system:  return L10n.tr("Sistem", "System")
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
    
    public var flag: String {
        switch self {
        case .system:  return "globe"
        case .turkish: return "🇹🇷"
        case .english: return "🇬🇧"
        }
    }
}

// MARK: - L10n

/// Hafif, sıfır-bağımlılık çeviri katmanı. Sistem dili Türkçe değilse otomatik İngilizce.
/// Kullanıcı `SettingsManager` üzerinden manuel olarak da seçebilir.
@MainActor
public enum L10n {
    
    /// O an aktif dil. `SettingsManager.shared.language` üzerinden değişir; `system` ise OS'tan gelir.
    public static var current: String {
        let pref = SettingsManager.shared.language
        switch pref {
        case .turkish: return "tr"
        case .english: return "en"
        case .system:
            // Sistem dili Türkçe ise TR, değilse EN.
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return code == "tr" ? "tr" : "en"
        }
    }
    
    /// İki-dilli kısa yardımcı: TR string'i ve EN string'i ver, aktif dile göre döner.
    public static func tr(_ turkish: String, _ english: String) -> String {
        current == "tr" ? turkish : english
    }
}

// MARK: - Anahtar Tabanlı Tablo (büyük metinler için)

@MainActor
public enum Strings {
    // Genel
    public static var appName: String { "Mirror Top" }
    
    // Onboarding
    public static var onboardingTitle: String           { L10n.tr("Mirror Top'a Hoş Geldiniz", "Welcome to Mirror Top") }
    public static var onboardingSubtitle: String        { L10n.tr(
        "Herhangi bir pencereyi canlı “Picture-in-Picture” olarak üst köşede tutmak için iki izne ihtiyacımız var.",
        "We need two permissions to keep any window as a live “Picture-in-Picture” on top.") }
    public static var permAccessibility: String         { L10n.tr("Erişilebilirlik", "Accessibility") }
    public static var permAccessibilityDesc: String    { L10n.tr(
        "Odaktaki pencereyi okumak ve etkileşim modunda fare/klavye olaylarını yönlendirmek için.",
        "To read the focused window and forward mouse/keyboard events in interaction mode.") }
    public static var permScreen: String                { L10n.tr("Ekran Kaydı", "Screen Recording") }
    public static var permScreenDesc: String           { L10n.tr(
        "Pencereyi yakalayıp canlı PiP paneline yansıtmak için (ScreenCaptureKit).",
        "To capture the window and stream it into the live PiP panel (ScreenCaptureKit).") }
    public static var permGranted: String               { L10n.tr("Verildi", "Granted") }
    public static var permMissing: String               { L10n.tr("Eksik", "Missing") }
    public static var permGrant: String                 { L10n.tr("İzin Ver", "Grant") }
    public static var permOpenSettings: String          { L10n.tr("Ayarları Aç", "Open Settings") }
    public static var permAllGranted: String            { L10n.tr("Tüm izinler verildi", "All permissions granted") }
    public static var permWaiting: String               { L10n.tr("İzin bekleniyor…", "Waiting for permission…") }
    public static var start: String                     { L10n.tr("Başla", "Get Started") }
    public static var later: String                     { L10n.tr("Daha Sonra", "Later") }
    public static var done: String                      { L10n.tr("Bitti", "Done") }
    public static var permsManageTitle: String          { L10n.tr("İzinleri Yönet", "Manage Permissions") }
    public static var permsManageSubtitle: String       { L10n.tr(
        "Mirror Top'un ihtiyaç duyduğu izinleri buradan görebilir veya güncelleyebilirsiniz.",
        "Review or update the permissions Mirror Top needs to function.") }
    public static var helpTooltip: String               { L10n.tr("Nasıl çalışır? — Yardım & Hakkında", "How does it work? — Help & About") }
    
    // Tagline / framing
    public static var pipTagline: String                 { L10n.tr(
        "Her pencere için canlı Picture-in-Picture",
        "Live Picture-in-Picture for any window") }
    public static var experimentalBadge: String          { L10n.tr("DENEYSEL", "EXPERIMENTAL") }
    public static var interactionExperimentalNote: String { L10n.tr(
        "Etkileşim Modu deneyseldir. Yazı seçme ve metin girişi gibi temel kullanımlarda çalışır; toolbar, font seçici veya menüler gibi karmaşık kontrollerde sinırlı sonuç verebilir. Bu, macOS'in güvenlik mimarisinden kaynaklanan bir kısıttır.",
        "Interaction Mode is experimental. It works for basic use like text selection and keyboard input; complex controls (toolbars, font pickers, popup menus) may be limited. This is a constraint of macOS's security architecture.") }
    
    // Menü Çubuğu
    public static var menuMirrorStart: String           { L10n.tr("Odaktaki Pencereyi PiP'le", "Float Focused Window as PiP") }
    public static var menuMirrorStop: String            { L10n.tr("PiP'i Durdur", "Stop PiP") }
    public static var menuInteractionOn: String         { L10n.tr("Etkileşim Modu: AÇIK", "Interaction Mode: ON") }
    public static var menuInteractionOff: String         { L10n.tr("Etkileşim Modu: KAPALI", "Interaction Mode: OFF") }
    public static var menuInteractionExperimental: String { L10n.tr("Etkileşim Modu (Deneysel)", "Interaction Mode (Experimental)") }
    public static var menuPermNeeded: String            { L10n.tr("İzin gerekli", "Permission required") }
    public static var menuOpenPerms: String             { L10n.tr("İzin Ekranını Aç…", "Open Permissions…") }
    public static var menuManagePerms: String           { L10n.tr("İzinleri Yönet…", "Manage Permissions…") }
    public static var menuHelp: String                  { L10n.tr("Yardım & Nasıl Çalışır…", "Help & How It Works…") }
    public static var menuShortcuts: String             { L10n.tr("Kısayollar", "Shortcuts") }
    public static var menuAbout: String                 { L10n.tr("Mirror Top Hakkında…", "About Mirror Top…") }
    public static var menuSettings: String              { L10n.tr("Ayarlar…", "Settings…") }
    public static var menuQuit: String                  { L10n.tr("Çıkış", "Quit") }
    
    // About sekmeleri
    public static var tabOverview: String               { L10n.tr("Genel Bakış", "Overview") }
    public static var tabHowItWorks: String             { L10n.tr("Nasıl Çalışır", "How It Works") }
    public static var tabShortcuts: String              { L10n.tr("Kısayollar", "Shortcuts") }
    public static var tabSettings: String               { L10n.tr("Ayarlar", "Settings") }
    public static var tabCredits: String                { L10n.tr("Künye", "Credits") }
    
    // About — Genel Bakış
    public static var ovWhatTitle: String               { L10n.tr("Bu uygulama ne işe yarar?", "What does this app do?") }
    public static var ovWhatBody: String                { L10n.tr(
        """
        Mirror Top, herhangi bir uygulama penceresini macOS üzerinde **canlı Picture-in-Picture** \
        olarak ekranın istediğiniz köşesinde tutmaya yarayan bir menü çubuğu aracıdır.
        Bir referans dökümanı, video oynatıcıyı, build/test çıktısını veya Slack DM'ini başka \
        uygulamalar üzerinde sürekli görünür tutmak istediğinizde işinize yarar.
        """,
        """
        Mirror Top is a menu-bar utility that keeps any application window as a **live \
        Picture-in-Picture** in the corner of your choice. It's perfect for keeping a reference \
        document, video player, build/test output or Slack DM persistently visible above other apps.
        """) }
    public static var ovProblemTitle: String            { L10n.tr("Hangi probleme çözüm sunuyor?", "What problem does it solve?") }
    public static var ovProblemBody1: String            { L10n.tr(
        """
        macOS, üçüncü parti uygulamaların başka bir uygulamanın pencere seviyesini doğrudan \
        değiştirmesine — yani Windows'taki PowerToys *Always on Top* gibi bir özellik sunmaya — \
        **SIP (System Integrity Protection)** kapatılmadan izin vermez.
        """,
        """
        macOS does not allow third-party apps to change another app's window level directly — \
        i.e. a feature like Windows PowerToys' *Always on Top* — unless **SIP \
        (System Integrity Protection)** is disabled.
        """) }
    public static var ovProblemBody2: String            { L10n.tr(
        """
        Mirror Top bu kısıtı, hedef pencereyi gerçekten "üste taşımak" yerine **canlı PiP \
        olarak yansıtarak** çözer. Sonuç: 60 FPS akışkan, gerçek pencerenin üstünde duran \
        şeffaf bir kopya — ve isteğe bağlı olarak temel fare/klavye etkileşimi.
        """,
        """
        Mirror Top works around this by **streaming the target window as a live PiP** instead of \
        physically raising it. The result is a smooth 60 FPS transparent clone hovering above \
        all other windows — with optional basic mouse/keyboard interaction.
        """) }
    public static var ovFeaturesTitle: String           { L10n.tr("Öne Çıkan Özellikler", "Highlights") }
    public static var ovFeat1: String                   { L10n.tr("Tek kısayolla odaktaki pencereyi anında PiP'e dönüştürür (⌘⌥T).", "Turn the focused window into a live PiP instantly with one shortcut (⌘⌥T).") }
    public static var ovFeat2: String                   { L10n.tr("Şeffaflık, köşeye yapışma (snap), boyut kısayolları (⌘⌥ 1/2/3) ve pozisyon hafızası.", "Opacity, snap-to-corner, size shortcuts (⌘⌥ 1/2/3) and remembered positions.") }
    public static var ovFeat3: String                   { L10n.tr("Hedef pencere yeniden boyutlandırıldığında PiP de canlı olarak ölçeklenir.", "The PiP scales live when the source window is resized.") }
    public static var ovFeat4: String                   { L10n.tr("Tüm Spaces'lerde görünür, şeffaf, native resize destekli `NSPanel`.", "Transparent floating `NSPanel` visible across all Spaces, with native resize.") }
    public static var ovFeat5: String                   { L10n.tr("Etkileşim Modu (deneysel) ile temel fare/klavye olayları hedef pencereye iletilebilir.", "Interaction Mode (experimental) can forward basic mouse/keyboard events to the target window.") }
    
    // About — Nasıl Çalışır
    public static var hwArchTitle: String               { L10n.tr("Mimari Akış", "Architecture Flow") }
    public static var hwStep1Title: String              { L10n.tr("Odaktaki Pencereyi Tespit Et", "Detect the Focused Window") }
    public static var hwStep1Desc: String               { L10n.tr(
        "Kullanıcı ⌘⌥T'ye bastığında **AXUIElement (Accessibility API)** üzerinden öndeki uygulamanın odak penceresini, başlığını, konum ve boyutunu okuruz.",
        "When the user hits ⌘⌥T, we read the frontmost app's focused window, title, position and size via **AXUIElement (Accessibility API)**.") }
    public static var hwStep2Title: String              { L10n.tr("CGWindowID Çözümle", "Resolve the CGWindowID") }
    public static var hwStep2Desc: String               { L10n.tr(
        "AX'in döndürdüğü `AXCGWindowIdentifier` öncelikli, başarısızsa `SCShareableContent` ile pencereyi başlık + konum eşleşmesiyle çözeriz.",
        "We prefer the `AXCGWindowIdentifier` returned by AX; if missing, we fall back to matching by title + position via `SCShareableContent`.") }
    public static var hwStep3Title: String              { L10n.tr("ScreenCaptureKit ile Yakala", "Capture with ScreenCaptureKit") }
    public static var hwStep3Desc: String               { L10n.tr(
        "Yalnızca o tek pencereyi `SCContentFilter` ile filtreleyip `SCStream` üzerinden 60 FPS yakalarız (`ignoreShadowsSingleWindow` ile çerçeve hizalaması korunur).",
        "We filter that single window via `SCContentFilter` and capture it at 60 FPS through `SCStream` (with `ignoreShadowsSingleWindow` for clean edges).") }
    public static var hwStep4Title: String              { L10n.tr("Şeffaf Floating Panel", "Transparent Floating Panel") }
    public static var hwStep4Desc: String               { L10n.tr(
        "Yakalanan kareler `.floating` seviyeli, `canJoinAllSpaces` özellikli özel bir `NSPanel` içindeki `CALayer`'a render edilir — pencere artık her zaman üstte.",
        "Captured frames are rendered to a `CALayer` inside a `.floating`-level `NSPanel` with `canJoinAllSpaces` — now the window is always on top.") }
    public static var hwStep5Title: String              { L10n.tr("Etkileşim Modu (Opsiyonel)", "Interaction Mode (Optional)") }
    public static var hwStep5Desc: String               { L10n.tr(
        "⌘⌥I ile etkinleştirilince, panel üstündeki fare/klavye olayları **CGEvent.postToPid** ile orijinal pencerenin PID'sine yönlendirilir.",
        "When enabled with ⌘⌥I, mouse/keyboard events on the panel are forwarded to the source window's PID via **CGEvent.postToPid**.") }
    
    public static var hwTechTitle: String               { L10n.tr("Kullanılan macOS Teknolojileri", "macOS Technologies Used") }
    public static var hwPrivacyTitle: String            { L10n.tr("Gizlilik", "Privacy") }
    public static var hwPrivacyBody: String             { L10n.tr(
        "Mirror Top **hiçbir veriyi internete göndermez**, telemetri toplamaz. Yakalanan tüm kareler yalnızca yerel olarak panele render edilir.",
        "Mirror Top **does not send any data over the internet** and collects no telemetry. All captured frames are rendered locally only.") }
    
    // About — Kısayollar
    public static var scToggleTitle: String             { L10n.tr("PiP'i Aç / Kapat", "Toggle PiP") }
    public static var scToggleDesc: String              { L10n.tr(
        "Şu anda odakta olan pencereyi PiP olarak üstte tutmaya başlar; tekrar basınca kapatır.",
        "Floats the currently focused window as a PiP on top; press again to stop.") }
    public static var scInteractionTitle: String        { L10n.tr("Etkileşim Modu (Deneysel)", "Interaction Mode (Experimental)") }
    public static var scInteractionDesc: String        { L10n.tr(
        "PiP açıkken; panele tıklamayı ve yazmayı orijinal pencereye iletmeye çalışır. Toolbar/font menüsü gibi karmaşık kontrollerde sınırlı çalışabilir.",
        "While the PiP is open, attempts to forward clicks/keys to the original window. Complex controls (toolbars, font pickers) may be limited.") }
    public static var scTipsTitle: String               { L10n.tr("İpuçları", "Tips") }
    public static var scTip1: String                    { L10n.tr("PiP'lemeden **önce** istediğiniz pencereyi tıklayıp aktif hâle getirin.", "Click and focus the desired window **before** starting the PiP.") }
    public static var scTip2: String                    { L10n.tr("Etkileşim Modu açıkken paneli **⌘+sürükle** ile taşıyabilirsiniz.", "While Interaction Mode is on, drag the panel with **⌘+drag**.") }
    public static var scTip3: String                    { L10n.tr("Birden fazla monitör varsa panel açıldığı ekranda kalır; sürükleyerek taşıyabilirsiniz.", "On multi-monitor setups the panel stays on the screen it opened; drag to move it.") }
    public static var scTip4: String                    { L10n.tr("PiP kalitesi düşerse hedef pencereyi biraz büyütüp tekrar deneyin.", "If quality drops, enlarge the source window slightly and try again.") }
    
    // About — Künye
    public static var crDeveloper: String               { L10n.tr("Geliştirici", "Developer") }
    public static var crProject: String                 { L10n.tr("Proje", "Project") }
    public static var crName: String                    { L10n.tr("Ad Soyad", "Name") }
    public static var crEmail: String                   { L10n.tr("E-posta", "Email") }
    public static var crGithub: String                  { "GitHub" }
    public static var crProjectName: String             { L10n.tr("Proje Adı", "Project Name") }
    public static var crVersion: String                 { L10n.tr("Versiyon", "Version") }
    public static var crTechnology: String              { L10n.tr("Teknoloji", "Technology") }
    public static var crAITitle: String                 { L10n.tr("Geliştirme Sürecinde Kullanılan Yapay Zekâlar", "AI Tools Used During Development") }
    public static var crAIRolePlanning: String          { L10n.tr("Planlama", "Planning") }
    public static var crAIRoleAnalysis: String          { L10n.tr("Analiz, Başlangıç Geliştirme", "Analysis, Initial Development") }
    public static var crAIRoleFinalize: String          { L10n.tr("Finalize, Bug Çözümleme, Arayüz Tasarımı", "Finalization, Bug Fixing, UI Design") }
    public static var crOpenSourceFooter: String        { L10n.tr("Açık kaynak.", "Open source.") }
    
    // About — Footer
    public static var openOnGithub: String              { L10n.tr("GitHub'da Aç", "Open on GitHub") }
    public static var feedback: String                  { L10n.tr("Geri Bildirim", "Feedback") }
    public static var close: String                     { L10n.tr("Kapat", "Close") }
    
    // Settings
    public static var settingsTitle: String             { L10n.tr("Ayarlar", "Settings") }
    public static var settingsLanguage: String          { L10n.tr("Arayüz Dili", "Interface Language") }
    public static var settingsLanguageHint: String     { L10n.tr("Sistem dili Türkçe değilse uygulama otomatik olarak İngilizce'ye geçer.", "If the system language isn't Turkish, the app automatically uses English.") }
    public static var settingsUpdates: String           { L10n.tr("Güncellemeler", "Updates") }
    public static var settingsAutoUpdateLabel: String  { L10n.tr("Açılışta güncellemeleri kontrol et", "Check for updates at launch") }
    public static var settingsAutoUpdateHint: String   { L10n.tr("Varsayılan olarak kapalıdır. Açarsanız her açılışta GitHub Releases sorgulanır.", "Disabled by default. When enabled, GitHub Releases is queried at every launch.") }
    public static var settingsCheckNow: String          { L10n.tr("Şimdi Kontrol Et", "Check Now") }
    public static var settingsCheckingNow: String       { L10n.tr("Kontrol ediliyor…", "Checking…") }
    public static var settingsLatestVersion: String     { L10n.tr("En son sürüm", "Latest version") }
    public static var settingsUpToDate: String          { L10n.tr("En güncel sürümü kullanıyorsunuz.", "You are running the latest version.") }
    public static var settingsUpdateAvailable: String   { L10n.tr("Yeni sürüm mevcut!", "A new version is available!") }
    public static var settingsViewRelease: String       { L10n.tr("Sürümü Görüntüle", "View Release") }
    public static var settingsLastChecked: String       { L10n.tr("Son kontrol", "Last checked") }
    public static var settingsNever: String             { L10n.tr("Hiç", "Never") }
    public static var settingsCheckFailed: String       { L10n.tr("Güncelleme kontrolü başarısız oldu.", "Update check failed.") }
    public static var settingsNoReleases: String        { L10n.tr(
        "GitHub'da henüz yayınlanmış bir sürüm bulunamadı.",
        "No releases have been published on GitHub yet.") }
    public static var settingsPermsTitle: String        { L10n.tr("İzinler", "Permissions") }
    public static var settingsResetTCC: String          { L10n.tr("İzinleri Sıfırla", "Reset Permissions") }
    public static var settingsResetTCCHint: String      { L10n.tr(
        "Eski build'lerden kalan izinleri temizler. Tıkladıktan sonra Sistem Ayarları'ndan izinleri yeniden vermeniz gerekir.",
        "Clears stale permissions from previous builds. After clicking, you'll need to re-grant in System Settings.") }
    public static var settingsResetDone: String         { L10n.tr("Sıfırlandı. Sistem Ayarları'ndan izin verin.", "Reset done. Please re-grant in System Settings.") }
    
    // Settings → Shortcuts
    public static var settingsShortcutsTitle: String    { L10n.tr("Kısayollar", "Shortcuts") }
    public static var settingsShortcutsHint: String     { L10n.tr(
        "Bu kısayolları dilediğiniz gibi değiştirebilirsiniz; tercihler güncellemeler arasında saklanır.",
        "You can change these shortcuts freely; preferences are kept across updates.") }
    public static var settingsShortcutCapture: String   { L10n.tr("PiP'i Aç/Kapat", "Toggle PiP") }
    public static var settingsShortcutInteraction: String { L10n.tr("Etkileşim Modu (Deneysel)", "Interaction Mode (Experimental)") }
    public static var settingsShortcutsResetAll: String { L10n.tr("Tüm Kısayolları Varsayılana Döndür", "Reset All Shortcuts to Defaults") }
    
    // Settings → Appearance
    public static var settingsAppearanceTitle: String    { L10n.tr("Görünüm", "Appearance") }
    public static var settingsOpacity: String            { L10n.tr("Opaklık", "Opacity") }
    public static var settingsOpacityHint: String        { L10n.tr(
        "PiP panelinin genel saydamlığı. Düşük değerler arka planı görmenize yardımcı olur.",
        "Overall opacity of the PiP panel. Lower values let you see what's behind it.") }
    public static var settingsGhostMode: String          { L10n.tr("Hayalet Modu", "Ghost Mode") }
    public static var settingsGhostModeHint: String      { L10n.tr(
        "Başka bir uygulama önplanda iken PiP otomatik olarak biraz daha şeffaflaşır.",
        "PiP becomes slightly more transparent when another app is in the foreground.") }
    public static var settingsGhostModeOpacity: String   { L10n.tr("Hayalet Opaklığı", "Ghost Opacity") }
    public static var settingsBorderToggle: String       { L10n.tr("Etkileşim modunda mavi çerçeve göster", "Show blue border in Interaction Mode") }
    public static var settingsBorderToggleHint: String   { L10n.tr(
        "Çerçeve, etkileşim modunun açık olduğunu görsel olarak belirtir.",
        "The border visually indicates that Interaction Mode is enabled.") }
    
    // Settings → Behavior (snap, persistence)
    public static var settingsBehaviorTitle: String      { L10n.tr("Davranış", "Behavior") }
    public static var settingsSnapToCorners: String      { L10n.tr("Köşelere yapışsın (Snap)", "Snap to corners") }
    public static var settingsSnapToCornersHint: String  { L10n.tr(
        "PiP'i ekran kenarına yaklaştırdığınızda otomatik olarak en yakın köşeye yapışır.",
        "When you drag the PiP near a screen edge, it snaps to the nearest corner.") }
    public static var settingsRememberPosition: String   { L10n.tr("Pencere için pozisyonu hatırla", "Remember position per window") }
    public static var settingsRememberPositionHint: String { L10n.tr(
        "Aynı uygulama/pencere için son kullandığınız panel pozisyonu ve boyutu otomatik geri yüklenir.",
        "The last panel position and size for the same app/window is automatically restored.") }
    
    // Size shortcuts
    public static var sizeSmall: String                  { L10n.tr("Küçük (¼)", "Small (¼)") }
    public static var sizeMedium: String                 { L10n.tr("Orta (½)", "Medium (½)") }
    public static var sizeLarge: String                  { L10n.tr("Büyük (1:1)", "Full (1:1)") }
    public static var scSizeTitle: String                { L10n.tr("Boyut Kısayolları", "Size Shortcuts") }
    public static var scSizeDesc: String                 { L10n.tr(
        "PiP açıkken panel boyutunu hızla değiştirin. Oran kaynak pencereye göredir.",
        "Quickly resize the PiP. Ratios are relative to the source window.") }
    
    // Dock-mode (overview / grid)
    public static var dockModeTitle: String              { L10n.tr("Dock Uygulaması", "Dock") }
    public static var dockModeEmpty: String              { L10n.tr(
        "Şu an aktif PiP yok. Bir pencereyi PiP'lemek için ⌘⌥T kısayolunu kullanın.",
        "No active PiPs right now. Use ⌘⌥T to float the focused window as a PiP.") }
    public static var dockModeOpen: String               { L10n.tr("Dock Uygulamasını Aç…", "Open Dock…") }
    public static var dockHover_configure: String        { L10n.tr("Ayarla", "Configure") }
    public static var dockHover_focus: String            { L10n.tr("Tek Başına Göster", "Bring to Front") }
    public static var dockHover_remove: String           { L10n.tr("Kaldır", "Remove") }
    public static var dockHover_reactivate: String       { L10n.tr("Yeniden Aç", "Reactivate") }
    public static var dockHint: String                   { L10n.tr(
        "Trackpad ile pinch-zoom yaparak grid yoğunluğunu değiştirebilirsiniz.",
        "Pinch with trackpad to change grid density.") }
    
    // Dock-mode tabs
    public static var dockTabPiPs: String                { L10n.tr("PiP'ler",      "PiPs") }
    public static var dockTabTransparency: String        { L10n.tr("Saydamlık",    "Transparency") }
    public static var dockTabAppearance: String          { L10n.tr("Tema",         "Theme") }
    public static var dockTabSettings: String            { L10n.tr("Ayarlar",      "Settings") }
    public static var dockTabAbout: String               { L10n.tr("Hakkında",     "About") }
    
    // Theme picker
    public static var themeTitle: String                 { L10n.tr("Tema Seçimi", "Theme") }
    public static var themeHint: String                  { L10n.tr(
        "Uygulama arayüzü ve PiP pencereleri seçtiğiniz temaya göre renklenir.",
        "App UI and PiP panels follow the chosen theme colors.") }
    
    // Transparency
    public static var transparencyMasterTitle: String    { L10n.tr("Ana Saydamlık (Master)", "Master Transparency") }
    public static var transparencyMasterHint: String     { L10n.tr(
        "Yeni açılan PiP'ler için varsayılan saydamlıktır.",
        "Default transparency applied to new PiP windows.") }
    public static var transparencyOverrideAll: String    { L10n.tr(
        "Tüm pencerelerin özel saydamlık değerlerini bu değerle ezer",
        "Override every window's custom transparency with this value") }
    public static var transparencyApplyToAll: String     { L10n.tr("Tüm Pencerelere Uygula", "Apply to All Windows") }
    public static var transparencyOverrideDone: String   { L10n.tr("Uygulandı.", "Applied.") }
    public static var transparencyActiveTitle: String    { L10n.tr("Aktif PiP'ler", "Active PiPs") }
    public static var transparencyEmpty: String          { L10n.tr(
        "Aktif PiP yok. Bir pencereyi PiP'lediğinizde burada ayrı bir saydamlık denetimi göreceksiniz.",
        "No active PiPs. Once you mirror a window, its transparency control appears here.") }
    public static var transparencyResetWindow: String    { L10n.tr("Sıfırla", "Reset") }
    
    // Menu — transparency
    public static var menuTransparency: String           { L10n.tr("Saydamlık", "Transparency") }
    public static var menuOpenDockApp: String            { L10n.tr("Dock Uygulamasını Aç…", "Open Dock App…") }
}

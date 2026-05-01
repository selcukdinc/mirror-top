import SwiftUI
import AppKit

/// Uygulama hakkında, "nasıl çalışır", ayarlar ve geliştirici/proje künyesi penceresi.
public struct AboutView: View {
    public var onClose: () -> Void
    
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var updates  = UpdateChecker.shared
    
    @State private var selectedTab: Tab = .overview
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case overview, howItWorks, shortcuts, settings, credits
        
        var id: String { rawValue }
        
        var titleKey: String {
            switch self {
            case .overview:   return Strings.tabOverview
            case .howItWorks: return Strings.tabHowItWorks
            case .shortcuts:  return Strings.tabShortcuts
            case .settings:   return Strings.tabSettings
            case .credits:    return Strings.tabCredits
            }
        }
        
        var icon: String {
            switch self {
            case .overview:   return "questionmark.circle"
            case .howItWorks: return "gearshape.2"
            case .shortcuts:  return "keyboard"
            case .settings:   return "slider.horizontal.3"
            case .credits:    return "person.crop.circle.badge.checkmark"
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                ScrollView {
                    content
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 480)
            }
            Divider()
            footer
        }
        .frame(width: 760, height: 580)
        // Dil değişince tüm metinler yenilensin diye view kimliği değişiyor.
        .id(settings.language.rawValue)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.appName).font(.title2).bold()
                HStack(spacing: 8) {
                    Text("\(Strings.crVersion) \(AppInfo.version)")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(AppInfo.stage)
                        .font(.caption.bold())
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(20)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Tab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon).frame(width: 18)
                        Text(tab.titleKey)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle()) // Tüm satır tıklanabilir olsun
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 210)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview:   overviewSection
        case .howItWorks: howItWorksSection
        case .shortcuts:  shortcutsSection
        case .settings:   SettingsSection()
        case .credits:    creditsSection
        }
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle(Strings.ovWhatTitle)
            Text(Strings.ovWhatBody)
            sectionTitle(Strings.ovProblemTitle)
            Text(Strings.ovProblemBody1)
            Text(Strings.ovProblemBody2)
            sectionTitle(Strings.ovFeaturesTitle)
            VStack(alignment: .leading, spacing: 10) {
                bullet(Strings.ovFeat1)
                bullet(Strings.ovFeat2)
                bullet(Strings.ovFeat3)
                bullet(Strings.ovFeat4)
                bullet(Strings.ovFeat5)
            }
        }
    }
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle(Strings.hwArchTitle)
            VStack(alignment: .leading, spacing: 10) {
                step(1, title: Strings.hwStep1Title, desc: Strings.hwStep1Desc)
                step(2, title: Strings.hwStep2Title, desc: Strings.hwStep2Desc)
                step(3, title: Strings.hwStep3Title, desc: Strings.hwStep3Desc)
                step(4, title: Strings.hwStep4Title, desc: Strings.hwStep4Desc)
                step(5, title: Strings.hwStep5Title, desc: Strings.hwStep5Desc)
            }
            
            sectionTitle(Strings.hwTechTitle)
            VStack(alignment: .leading, spacing: 8) {
                techRow("ScreenCaptureKit", L10n.tr(
                    "Pencere bazlı yüksek performans yakalama (`SCStream`, `SCContentFilter`).",
                    "High-performance per-window capture (`SCStream`, `SCContentFilter`)."))
                techRow("AppKit / NSPanel", L10n.tr(
                    "Şeffaf, tüm Spaces'te görünen, native resize destekli yüzer pencere.",
                    "Transparent floating panel visible across Spaces with native resize."))
                techRow("SwiftUI + Combine", L10n.tr(
                    "Reaktif UI ve `@ObservableObject` izin yöneticisi (canlı izin durumu).",
                    "Reactive UI and an `@ObservableObject` permissions manager (live status)."))
                techRow("Accessibility (AX) API", L10n.tr(
                    "Odaktaki pencerenin meta verisini güvenli okumak için.",
                    "To safely read the focused window's metadata."))
                techRow("Core Graphics + CGEvent", L10n.tr(
                    "Yakalanan karelerin render'ı ve etkileşim modunda olay enjeksiyonu.",
                    "Frame rendering and event injection for interaction mode."))
                techRow("Carbon HotKey API", L10n.tr(
                    "Sistem genelinde global kısayollar (`RegisterEventHotKey`).",
                    "System-wide global hotkeys (`RegisterEventHotKey`)."))
                techRow("VideoToolbox", L10n.tr(
                    "`CVPixelBuffer → CGImage` dönüşümü (`VTCreateCGImageFromCVPixelBuffer`).",
                    "`CVPixelBuffer → CGImage` conversion (`VTCreateCGImageFromCVPixelBuffer`)."))
            }
            
            sectionTitle(Strings.hwPrivacyTitle)
            Text(Strings.hwPrivacyBody)
        }
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle(L10n.tr("Klavye Kısayolları", "Keyboard Shortcuts"))
            shortcutRow(keys: keyTokens(SettingsManager.shared.captureShortcut),
                        title: Strings.scToggleTitle, desc: Strings.scToggleDesc)
            shortcutRow(keys: keyTokens(SettingsManager.shared.interactionShortcut),
                        title: Strings.scInteractionTitle, desc: Strings.scInteractionDesc)
            
            // Experimental uyarı bandı — etkileşim modunun sınırlarını netleştirir.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "flask.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(Strings.experimentalBadge)
                            .font(.caption.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .foregroundStyle(.orange)
                    }
                    Text(Strings.interactionExperimentalNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.25), lineWidth: 1))
            
            sectionTitle(Strings.scSizeTitle)
            Text(Strings.scSizeDesc)
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                shortcutRow(keys: ["⌘", "⌥", "1"], title: Strings.sizeSmall, desc: "")
                shortcutRow(keys: ["⌘", "⌥", "2"], title: Strings.sizeMedium, desc: "")
                shortcutRow(keys: ["⌘", "⌥", "3"], title: Strings.sizeLarge, desc: "")
            }
            
            sectionTitle(Strings.scTipsTitle)
            VStack(alignment: .leading, spacing: 10) {
                bullet(Strings.scTip1)
                bullet(Strings.scTip2)
                bullet(Strings.scTip3)
                bullet(Strings.scTip4)
            }
        }
    }
    
    /// Shortcut'tan görsel tokenlar (her sembol bir ayrı kutu olarak görünsün).
    private func keyTokens(_ s: Shortcut) -> [String] {
        let display = s.displayString
        var result: [String] = []
        var current = ""
        for ch in display {
            if ["⌃", "⌥", "⇧", "⌘"].contains(String(ch)) {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(String(ch))
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionTitle(Strings.crDeveloper)
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "person.fill", label: Strings.crName, value: AppInfo.developerName)
                infoRow(icon: "envelope.fill", label: Strings.crEmail,
                        value: AppInfo.developerEmail,
                        link: "mailto:\(AppInfo.developerEmail)")
                infoRow(icon: "link", label: Strings.crGithub,
                        value: AppInfo.developerGithub,
                        link: AppInfo.developerGithub)
            }
            
            sectionTitle(Strings.crProject)
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "app.badge", label: Strings.crProjectName, value: AppInfo.projectName)
                infoRow(icon: "tag.fill", label: Strings.crVersion,
                        value: "\(AppInfo.version) \(AppInfo.stage)")
                infoRow(icon: "swift", label: Strings.crTechnology,
                        value: "Swift • SwiftUI • AppKit • ScreenCaptureKit")
                infoRow(icon: "link", label: Strings.crGithub,
                        value: AppInfo.projectGithub,
                        link: AppInfo.projectGithub)
            }
            
            sectionTitle(Strings.crAITitle)
            VStack(alignment: .leading, spacing: 6) {
                aiRow("Gemini 3 (Hızlı)",      role: Strings.crAIRolePlanning)
                aiRow("Gemini 3.1 Pro (High)", role: Strings.crAIRoleAnalysis)
                aiRow("Claude Opus 4.7",       role: Strings.crAIRoleFinalize)
            }
            
            // String(year) ile veriyoruz çünkü SwiftUI Text Int interpolasyonu locale'a göre
            // "2.026" gibi bin ayraçlı format basıyor; string olarak göndererek formatlamayı engelliyoruz.
            Text("© \(String(Calendar.current.component(.year, from: Date()))) \(AppInfo.developerName) — \(Strings.crOpenSourceFooter)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Link(destination: URL(string: AppInfo.projectGithub)!) {
                Label(Strings.openOnGithub, systemImage: "link")
            }.buttonStyle(.bordered)
            Link(destination: URL(string: "mailto:\(AppInfo.developerEmail)")!) {
                Label(Strings.feedback, systemImage: "envelope")
            }.buttonStyle(.bordered)
            Spacer()
            Button(Strings.close) { onClose() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }.padding(16)
    }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline).padding(.top, 4)
    }
    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint).font(.callout).padding(.top, 2)
            Text(text)
        }
    }
    
    private func step(_ n: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.callout.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func techRow(_ name: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .font(.callout.bold().monospaced())
                .frame(width: 170, alignment: .leading)
                .foregroundStyle(.tint)
            Text(desc).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func shortcutRow(keys: [String], title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    Text(k).font(.callout.bold().monospaced())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                }
            }.frame(width: 130, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    
    private func infoRow(icon: String, label: String, value: String, link: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(.secondary)
            Text(label).font(.callout).foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            if let link, let url = URL(string: link) {
                Link(value, destination: url).font(.callout)
            } else {
                Text(value).font(.callout)
            }
            Spacer()
        }
    }
    
    private func aiRow(_ name: String, role: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(.tint)
            Text(name).font(.callout.bold())
            Text("—").foregroundStyle(.secondary)
            Text(role).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Settings Section

private struct SettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var updates  = UpdateChecker.shared
    @State private var resetMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Dil
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.settingsLanguage).font(.headline)
                Picker(selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)
                Text(Strings.settingsLanguageHint)
                    .font(.callout).foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Görünüm
            VStack(alignment: .leading, spacing: 12) {
                Text(Strings.settingsAppearanceTitle).font(.headline)
                
                // Opaklık
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Strings.settingsOpacity)
                        Spacer()
                        Text("\(Int(settings.opacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.opacity, in: 0.2...1.0)
                        .frame(maxWidth: 380)
                    Text(Strings.settingsOpacityHint)
                        .font(.callout).foregroundStyle(.secondary)
                }
                
                // Hayalet modu
                Toggle(Strings.settingsGhostMode, isOn: $settings.ghostMode)
                Text(Strings.settingsGhostModeHint)
                    .font(.callout).foregroundStyle(.secondary)
                if settings.ghostMode {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(Strings.settingsGhostModeOpacity)
                            Spacer()
                            Text("\(Int(settings.ghostOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.ghostOpacity, in: 0.1...0.9)
                            .frame(maxWidth: 380)
                    }
                }
                
                // Etkileşim çerçevesi
                Toggle(Strings.settingsBorderToggle, isOn: $settings.showInteractionBorder)
                Text(Strings.settingsBorderToggleHint)
                    .font(.callout).foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Davranış
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsBehaviorTitle).font(.headline)
                Toggle(Strings.settingsSnapToCorners, isOn: $settings.snapToCorners)
                Text(Strings.settingsSnapToCornersHint)
                    .font(.callout).foregroundStyle(.secondary)
                Toggle(Strings.settingsRememberPosition, isOn: $settings.rememberPositionPerWindow)
                Text(Strings.settingsRememberPositionHint)
                    .font(.callout).foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Güncellemeler
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsUpdates).font(.headline)
                Toggle(Strings.settingsAutoUpdateLabel, isOn: $settings.autoUpdateCheck)
                Text(Strings.settingsAutoUpdateHint)
                    .font(.callout).foregroundStyle(.secondary)
                
                HStack(spacing: 10) {
                    Button {
                        Task { _ = await updates.check() }
                    } label: {
                        if updates.isChecking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text(Strings.settingsCheckingNow)
                            }
                        } else {
                            Label(Strings.settingsCheckNow, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updates.isChecking)
                    
                    Spacer()
                    
                    Text("\(Strings.settingsLastChecked): \(formattedLastCheck)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                updateResultView
            }
            
            Divider()
            
            // Kısayollar
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsShortcutsTitle).font(.headline)
                Text(Strings.settingsShortcutsHint)
                    .font(.callout).foregroundStyle(.secondary)
                
                HStack {
                    Text(Strings.settingsShortcutCapture)
                        .frame(width: 200, alignment: .leading)
                    ShortcutRecorderView(shortcut: $settings.captureShortcut,
                                         defaultValue: .defaultCapture)
                    Spacer()
                }
                
                HStack {
                    Text(Strings.settingsShortcutInteraction)
                        .frame(width: 200, alignment: .leading)
                    ShortcutRecorderView(shortcut: $settings.interactionShortcut,
                                         defaultValue: .defaultInteraction)
                    Spacer()
                }
                
                Button {
                    settings.resetShortcutsToDefaults()
                } label: {
                    Label(Strings.settingsShortcutsResetAll, systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            
            Divider()
            
            // İzinler
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsPermsTitle).font(.headline)
                Text(Strings.settingsResetTCCHint)
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        PermissionResetHelper.resetAllPermissions()
                        resetMessage = Strings.settingsResetDone
                    } label: {
                        Label(Strings.settingsResetTCC, systemImage: "arrow.counterclockwise.circle")
                    }
                    .buttonStyle(.bordered)
                    
                    if let msg = resetMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                    }
                }
            }
        }
    }
    
    private var formattedLastCheck: String {
        guard let d = settings.lastUpdateCheck else { return Strings.settingsNever }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
    
    @ViewBuilder
    private var updateResultView: some View {
        if let result = updates.lastResult {
            switch result {
            case .upToDate(let current):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("\(Strings.settingsUpToDate) (\(current))")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.10)))
                
            case .updateAvailable(let info):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.orange)
                        Text(Strings.settingsUpdateAvailable).bold()
                    }
                    Text("\(Strings.settingsLatestVersion): \(info.latestVersion)  ·  \(Strings.crVersion): \(info.currentVersion)")
                        .font(.callout).foregroundStyle(.secondary)
                    Button {
                        UpdateChecker.shared.openLatestReleasePage()
                    } label: {
                        Label(Strings.settingsViewRelease, systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                
            case .noReleases:
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text(Strings.settingsNoReleases).font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.10)))
                
            case .failed(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text("\(Strings.settingsCheckFailed) (\(message))").font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.10)))
            }
        }
    }
}

// MARK: - App Bilgileri

public enum AppInfo {
    public static let projectName     = "Mirror Top"
    /// Bundle'dan dinamik okur — her build'de pbxproj'taki MARKETING_VERSION güncellenir.
    public static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    /// Bundle build numarası.
    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    public static let stage           = "Alpha"
    public static let projectGithub   = "https://github.com/selcukdinc/mirror-top"
    
    public static let developerName   = "Selçuk DİNÇ"
    public static let developerEmail  = "selcukdinc@devloop.com.tr"
    public static let developerGithub = "https://github.com/selcukdinc"
}

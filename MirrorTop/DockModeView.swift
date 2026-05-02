import SwiftUI
import AppKit

/// Dock-mode: artık sadece grid değil — uygulamanın **merkezi profesyonel paneli**.
/// PiP yönetimi, saydamlık denetimi, tema ve genel ayarlara buradan ulaşılır.
public struct DockModeView: View {
    @ObservedObject private var registry = MirrorRegistry.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var selectedTab: Tab = .pips
    
    public var openAbout: () -> Void = {}
    public var openPermissions: () -> Void = {}
    
    public init(openAbout: @escaping () -> Void = {},
                openPermissions: @escaping () -> Void = {}) {
        self.openAbout = openAbout
        self.openPermissions = openPermissions
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case pips, transparency, theme, settings, about
        var id: String { rawValue }
        @MainActor var title: String {
            switch self {
            case .pips:         return Strings.dockTabPiPs
            case .transparency: return Strings.dockTabTransparency
            case .theme:        return Strings.dockTabAppearance
            case .settings:     return Strings.dockTabSettings
            case .about:        return Strings.dockTabAbout
            }
        }
        var icon: String {
            switch self {
            case .pips:         return "rectangle.on.rectangle"
            case .transparency: return "circle.lefthalf.filled"
            case .theme:        return "paintpalette"
            case .settings:     return "slider.horizontal.3"
            case .about:        return "info.circle"
            }
        }
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 560)
        }
        .frame(minWidth: 880, minHeight: 560)
        .background(VisualEffectBackground())
        .preferredColorScheme(settings.theme.colorScheme)
        .tint(settings.theme.accent)
        .id(settings.language.rawValue + settings.theme.rawValue)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(Strings.appName).font(.callout.bold())
                    Text(Strings.dockModeTitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
            
            Divider().padding(.horizontal, 8).padding(.bottom, 6)
            
            ForEach(Tab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon).frame(width: 18)
                        Text(tab.title)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("v\(AppInfo.version) — \(AppInfo.stage)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .padding(8)
        .frame(width: 220)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .pips:         pipsTab
        case .transparency: TransparencyTab()
        case .theme:        ThemeTab()
        case .settings:     SettingsCompactTab()
        case .about:        AboutCompactTab(openAbout: openAbout, openPermissions: openPermissions)
        }
    }
    
    // MARK: - PiPs Tab
    
    @State private var gridScale: CGFloat = 1.0       // smooth pinch için canlı ölçek
    @State private var pinchAccumulator: CGFloat = 1.0
    @State private var configuredFor: String? = nil   // Hangi cell'in config popover'ı açık
    
    private var pipsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(Strings.dockModeTitle).font(.title2).bold()
                Spacer()
                Text(Strings.dockHint)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if registry.snapshots.isEmpty {
                emptyState
            } else {
                pipsGrid
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(Strings.dockModeEmpty)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
    
    /// Smooth pinch — minimum hücre genişliği (200pt) gridScale ile çarpılır.
    /// `LazyVGrid(.adaptive)` kalan alanı doldurarak akıcı ve native bir hisse erişir.
    @ViewBuilder
    private var pipsGrid: some View {
        let baseMin: CGFloat = 200
        let minWidth = max(110, min(420, baseMin * gridScale))
        let cols = [GridItem(.adaptive(minimum: minWidth, maximum: 600), spacing: 14)]
        LazyVGrid(columns: cols, spacing: 14) {
            ForEach(registry.snapshots) { snap in
                DockCell(snapshot: snap)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: minWidth)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / pinchAccumulator
                    pinchAccumulator = value
                    let newScale = max(0.55, min(2.1, gridScale * delta))
                    gridScale = newScale
                }
                .onEnded { _ in pinchAccumulator = 1.0 }
        )
    }
}

// MARK: - Dock Cell

private struct DockCell: View {
    let snapshot: MirrorRegistry.Snapshot
    @State private var isHovering = false
    @State private var showingConfig = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                preview
                if snapshot.isActive {
                    Text("LIVE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(.white)
                        .padding(8)
                }
                if isHovering {
                    overlayButtons
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.appName).font(.callout.bold()).lineLimit(1)
                Text(snapshot.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07)))
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { reactivate() }
        .popover(isPresented: $showingConfig, arrowEdge: .top) {
            CellConfigPopover(snapshot: snapshot)
                .frame(width: 320)
        }
    }
    
    @ViewBuilder
    private var preview: some View {
        ZStack {
            Color.black.opacity(0.06)
            if let img = snapshot.image {
                Image(decorative: img, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    if !snapshot.isActive {
                        Text(Strings.dockHover_reactivate)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .aspectRatio(16.0/10.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private var overlayButtons: some View {
        HStack(spacing: 6) {
            actionButton(systemName: "gearshape.fill", help: Strings.dockHover_configure) {
                showingConfig.toggle()
            }
            if snapshot.isActive {
                actionButton(systemName: "rectangle.on.rectangle", help: Strings.dockHover_focus) {
                    StreamManager.shared.bringActivePanelToFront()
                }
            } else {
                actionButton(systemName: "play.circle.fill", help: Strings.dockHover_reactivate) {
                    reactivate()
                }
            }
            actionButton(systemName: "xmark.circle.fill", help: Strings.dockHover_remove) {
                MirrorRegistry.shared.remove(snapshot)
            }
        }
    }
    
    private func reactivate() {
        let bid = snapshot.bundleID
        let title = snapshot.title
        Task { @MainActor in
            _ = await StreamManager.shared.reactivate(bundleID: bid, title: title)
        }
    }
    
    private func actionButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Per-cell Config Popover

private struct CellConfigPopover: View {
    let snapshot: MirrorRegistry.Snapshot
    @ObservedObject private var settings = SettingsManager.shared
    @State private var opacity: Double = 1.0
    
    private var titleHash: String { String(format: "%08x", snapshot.title.hashValue & 0xFFFFFFFF) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snapshot.appName).font(.headline)
            Text(snapshot.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Strings.settingsOpacity)
                    Spacer()
                    Text("\(Int(opacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $opacity, in: 0.2...1.0)
                    .onChange(of: opacity) { _, new in
                        settings.saveWindowOpacity(new,
                                                   forBundleID: snapshot.bundleID,
                                                   titleHash: titleHash)
                        // Aktif panelse anında uygulansın.
                        if snapshot.isActive {
                            StreamManager.shared.setActivePanelOpacity(new)
                        }
                    }
            }
            HStack {
                Button(Strings.transparencyResetWindow) {
                    settings.clearWindowOpacity(forBundleID: snapshot.bundleID, titleHash: titleHash)
                    opacity = settings.opacity
                    if snapshot.isActive {
                        StreamManager.shared.setActivePanelOpacity(settings.opacity)
                    }
                }
                .buttonStyle(.bordered)
                Spacer()
                if !snapshot.isActive {
                    Button(Strings.dockHover_reactivate) {
                        Task { @MainActor in
                            _ = await StreamManager.shared.reactivate(bundleID: snapshot.bundleID,
                                                                      title: snapshot.title)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
        .onAppear {
            opacity = settings.windowOpacity(forBundleID: snapshot.bundleID, titleHash: titleHash) ?? settings.opacity
        }
    }
}

// MARK: - Transparency Tab

private struct TransparencyTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var registry = MirrorRegistry.shared
    @State private var showOverrideToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Master
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.transparencyMasterTitle).font(.title3).bold()
                Text(Strings.transparencyMasterHint).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text(Strings.settingsOpacity)
                    Spacer()
                    Text("\(Int(settings.opacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.opacity, in: 0.2...1.0)
                Text(Strings.transparencyOverrideAll).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button {
                        settings.clearAllWindowOpacityOverrides()
                        // Aktif panelin per-window override'ı silindiği için master uygulansın.
                        StreamManager.shared.setActivePanelOpacity(settings.opacity)
                        showOverrideToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showOverrideToast = false
                        }
                    } label: {
                        Label(Strings.transparencyApplyToAll, systemImage: "wand.and.rays")
                    }
                    .buttonStyle(.borderedProminent)
                    if showOverrideToast {
                        Label(Strings.transparencyOverrideDone, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                    }
                    Spacer()
                }
                Toggle(Strings.settingsGhostMode, isOn: $settings.ghostMode)
                if settings.ghostMode {
                    HStack {
                        Text(Strings.settingsGhostModeOpacity)
                        Spacer()
                        Text("\(Int(settings.ghostOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.ghostOpacity, in: 0.1...0.9)
                }
            }
            
            Divider()
            
            // Active per-window list
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.transparencyActiveTitle).font(.title3).bold()
                if registry.snapshots.isEmpty {
                    Text(Strings.transparencyEmpty).font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(registry.snapshots) { snap in
                        TransparencyRow(snapshot: snap)
                    }
                }
            }
        }
    }
}

private struct TransparencyRow: View {
    let snapshot: MirrorRegistry.Snapshot
    @ObservedObject private var settings = SettingsManager.shared
    @State private var opacity: Double = 1.0
    
    private var titleHash: String { String(format: "%08x", snapshot.title.hashValue & 0xFFFFFFFF) }
    
    var body: some View {
        HStack(spacing: 12) {
            // Mini önizleme
            ZStack {
                Color.black.opacity(0.08)
                if let img = snapshot.image {
                    Image(decorative: img, scale: 1.0, orientation: .up)
                        .resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "rectangle.on.rectangle")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snapshot.appName).font(.callout.bold()).lineLimit(1)
                    if snapshot.isActive {
                        Text("LIVE").font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                            .foregroundStyle(.white)
                    }
                }
                Text(snapshot.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Slider(value: $opacity, in: 0.2...1.0)
                        .onChange(of: opacity) { _, new in
                            settings.saveWindowOpacity(new,
                                                       forBundleID: snapshot.bundleID,
                                                       titleHash: titleHash)
                            if snapshot.isActive {
                                StreamManager.shared.setActivePanelOpacity(new)
                            }
                        }
                    Text("\(Int(opacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            Button {
                settings.clearWindowOpacity(forBundleID: snapshot.bundleID, titleHash: titleHash)
                opacity = settings.opacity
                if snapshot.isActive {
                    StreamManager.shared.setActivePanelOpacity(settings.opacity)
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .help(Strings.transparencyResetWindow)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .onAppear {
            opacity = settings.windowOpacity(forBundleID: snapshot.bundleID, titleHash: titleHash) ?? settings.opacity
        }
    }
}

// MARK: - Theme Tab

private struct ThemeTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Strings.themeTitle).font(.title2).bold()
            Text(Strings.themeHint).font(.callout).foregroundStyle(.secondary)
            
            let cols = [GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 14)]
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeCard(theme: theme, isSelected: settings.theme == theme) {
                        settings.theme = theme
                    }
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    LinearGradient(colors: gradientColors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: theme.symbol)
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white)
                }
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                HStack {
                    Text(theme.displayName).font(.callout.bold())
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? theme.accent : Color.primary.opacity(0.07),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var gradientColors: [Color] {
        switch theme {
        case .classic:  return [.blue.opacity(0.45), .indigo.opacity(0.55)]
        case .midnight: return [.black, Color(red: 0.1, green: 0.1, blue: 0.25)]
        case .ocean:    return [Color(red: 0.0, green: 0.5, blue: 0.8),
                                Color(red: 0.0, green: 0.85, blue: 0.95)]
        case .sunset:   return [Color(red: 0.95, green: 0.45, blue: 0.30),
                                Color(red: 0.55, green: 0.2,  blue: 0.55)]
        }
    }
}

// MARK: - Settings (compact) Tab

private struct SettingsCompactTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Strings.settingsTitle).font(.title2).bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.settingsLanguage).font(.headline)
                Picker(selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsBehaviorTitle).font(.headline)
                Toggle(Strings.settingsSnapToCorners, isOn: $settings.snapToCorners)
                Toggle(Strings.settingsRememberPosition, isOn: $settings.rememberPositionPerWindow)
                Toggle(Strings.settingsBorderToggle, isOn: $settings.showInteractionBorder)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text(Strings.settingsShortcutsTitle).font(.headline)
                HStack {
                    Text(Strings.settingsShortcutCapture).frame(width: 200, alignment: .leading)
                    ShortcutRecorderView(shortcut: $settings.captureShortcut, defaultValue: .defaultCapture)
                    Spacer()
                }
                HStack {
                    Text(Strings.settingsShortcutInteraction).frame(width: 200, alignment: .leading)
                    ShortcutRecorderView(shortcut: $settings.interactionShortcut, defaultValue: .defaultInteraction)
                    Spacer()
                }
                Button {
                    settings.resetShortcutsToDefaults()
                } label: {
                    Label(Strings.settingsShortcutsResetAll, systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - About (compact) Tab

private struct AboutCompactTab: View {
    let openAbout: () -> Void
    let openPermissions: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Header (logo + ad + versiyon)
            HStack(spacing: 14) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 52, height: 52)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
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
            
            // Geliştirici
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.crDeveloper).font(.headline)
                infoRow(icon: "person.fill", label: Strings.crName, value: AppInfo.developerName)
                infoRow(icon: "envelope.fill", label: Strings.crEmail,
                        value: AppInfo.developerEmail,
                        link: "mailto:\(AppInfo.developerEmail)")
                infoRow(icon: "link", label: Strings.crGithub,
                        value: AppInfo.developerGithub,
                        link: AppInfo.developerGithub)
            }
            
            // Proje
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.crProject).font(.headline)
                infoRow(icon: "app.badge", label: Strings.crProjectName, value: AppInfo.projectName)
                infoRow(icon: "tag.fill", label: Strings.crVersion,
                        value: "\(AppInfo.version) \(AppInfo.stage)")
                infoRow(icon: "swift", label: Strings.crTechnology,
                        value: "Swift • SwiftUI • AppKit • ScreenCaptureKit")
                infoRow(icon: "link", label: Strings.crGithub,
                        value: AppInfo.projectGithub,
                        link: AppInfo.projectGithub)
            }
            
            // AI Künyesi
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.crAITitle).font(.headline)
                aiRow("Gemini 3 (Hızlı)",      role: Strings.crAIRolePlanning)
                aiRow("Gemini 3.1 Pro (High)", role: Strings.crAIRoleAnalysis)
                aiRow("Claude Opus 4.7",       role: Strings.crAIRoleFinalize)
            }
            
            Divider()
            
            // Aksiyon butonları
            HStack(spacing: 10) {
                Button {
                    openAbout()
                } label: {
                    Label(Strings.menuAbout, systemImage: "info.circle")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    openPermissions()
                } label: {
                    Label(Strings.menuManagePerms, systemImage: "lock.shield")
                }
                .buttonStyle(.bordered)
                Spacer()
                Link(destination: URL(string: AppInfo.projectGithub)!) {
                    Label(Strings.openOnGithub, systemImage: "link")
                }
                .buttonStyle(.bordered)
                Link(destination: URL(string: "mailto:\(AppInfo.developerEmail)")!) {
                    Label(Strings.feedback, systemImage: "envelope")
                }
                .buttonStyle(.bordered)
            }
            
            Text("© \(String(Calendar.current.component(.year, from: Date()))) \(AppInfo.developerName) — \(Strings.crOpenSourceFooter)")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

/// macOS native blur arka plan.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

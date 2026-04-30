import SwiftUI
import AppKit

/// Uygulama hakkında, "nasıl çalışır" ve geliştirici/proje künyesi penceresi.
/// Menü çubuğundan veya onboarding üzerinden açılır.
public struct AboutView: View {
    public var onClose: () -> Void
    
    @State private var selectedTab: Tab = .overview
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case overview   = "Genel Bakış"
        case howItWorks = "Nasıl Çalışır"
        case shortcuts  = "Kısayollar"
        case credits    = "Künye"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .overview:   return "questionmark.circle"
            case .howItWorks: return "gearshape.2"
            case .shortcuts:  return "keyboard"
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
                .frame(minWidth: 460)
            }
            
            Divider()
            footer
        }
        .frame(width: 720, height: 540)
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
                Text("Mirror Top")
                    .font(.title2).bold()
                HStack(spacing: 8) {
                    Text("Versiyon \(AppInfo.version)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
        .frame(width: 200)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview:   overviewSection
        case .howItWorks: howItWorksSection
        case .shortcuts:  shortcutsSection
        case .credits:    creditsSection
        }
    }
    
    // MARK: Genel Bakış
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Bu uygulama ne işe yarar?")
            Text("""
                 Mirror Top, herhangi bir uygulama penceresini macOS üzerinde **\"Always on Top\" \
                 (her zaman üstte)** hâle getirmeye yarayan bir menü çubuğu aracıdır.
                 Bir referans dökümanı, video oynatıcıyı, terminali veya küçük bir izleme penceresini \
                 başka uygulamalar üzerinde sürekli görünür tutmak istediğinizde işinize yarar.
                 """)
            
            sectionTitle("Hangi probleme çözüm sunuyor?")
            Text("""
                 Windows'taki PowerToys *Always on Top* özelliğinin macOS'te yerleşik bir karşılığı yoktur. \
                 macOS, üçüncü parti uygulamaların başka bir uygulamanın pencere seviyesini doğrudan \
                 değiştirmesine **SIP (System Integrity Protection)** kapatılmadan izin vermez.
                 """)
            Text("""
                 Mirror Top bu kısıtı, hedef pencereyi gerçekten "üste taşımak" yerine **canlı olarak \
                 yansıtarak** (mirror) çözer. Sonuç: 60 FPS akışkan, gerçek pencerenin üstünde duran \
                 şeffaf bir kopya — ve isteğe bağlı olarak fare/klavye etkileşimi.
                 """)
            
            sectionTitle("Öne Çıkan Özellikler")
            VStack(alignment: .leading, spacing: 10) {
                bullet("Tek kısayolla odaktaki pencereyi anında yansıtır (⌘⌥T).")
                bullet("Etkileşim Modu ile yansıtılan pencereye fare/klavye olayları gönderilir (⌘⌥I).")
                bullet("Hedef pencere yeniden boyutlandırıldığında yansıma da canlı olarak ölçeklenir.")
                bullet("Tüm Spaces'lerde görünür, şeffaf, native resize destekli `NSPanel`.")
                bullet("macOS 5+ dakika sonunda akışı kesse bile **sessiz yeniden başlatma** ile flicker yaşatmadan devam eder.")
            }
        }
    }
    
    // MARK: Nasıl Çalışır
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Mimari Akış")
            VStack(alignment: .leading, spacing: 10) {
                step(1, title: "Odaktaki Pencereyi Tespit Et",
                     desc: "Kullanıcı ⌘⌥T'ye bastığında **AXUIElement (Accessibility API)** üzerinden öndeki uygulamanın odak penceresini, başlığını, konum ve boyutunu okuruz.")
                step(2, title: "CGWindowID Çözümle",
                     desc: "AX'in döndürdüğü `AXCGWindowIdentifier` öncelikli, başarısızsa `SCShareableContent` ile pencereyi başlık + konum eşleşmesiyle çözeriz.")
                step(3, title: "ScreenCaptureKit ile Yakala",
                     desc: "Yalnızca o tek pencereyi `SCContentFilter` ile filtreleyip `SCStream` üzerinden 60 FPS yakalarız (`ignoreShadowsSingleWindow` ile çerçeve hizalaması korunur).")
                step(4, title: "Şeffaf Floating Panel",
                     desc: "Yakalanan kareler `.floating` seviyeli, `canJoinAllSpaces` özellikli özel bir `NSPanel` içindeki `CALayer`'a render edilir — pencere artık her zaman üstte.")
                step(5, title: "Etkileşim Modu (Opsiyonel)",
                     desc: "⌘⌥I ile etkinleştirilince, panel üstündeki fare/klavye olayları **CGEvent.postToPid** ile orijinal pencerenin PID'sine yönlendirilir.")
            }
            
            sectionTitle("Kullanılan macOS Teknolojileri")
            VStack(alignment: .leading, spacing: 8) {
                techRow("ScreenCaptureKit",
                        "Pencere bazlı yüksek performans yakalama (`SCStream`, `SCContentFilter`).")
                techRow("AppKit / NSPanel",
                        "Şeffaf, tüm Spaces'te görünen, native resize destekli yüzer pencere.")
                techRow("SwiftUI + Combine",
                        "Reaktif UI ve `@ObservableObject` izin yöneticisi (canlı izin durumu).")
                techRow("Accessibility (AX) API",
                        "Odaktaki pencerenin meta verisini güvenli okumak için.")
                techRow("Core Graphics + CGEvent",
                        "Yakalanan karelerin render'ı ve etkileşim modunda olay enjeksiyonu.")
                techRow("Carbon HotKey API",
                        "Sistem genelinde global kısayollar (`RegisterEventHotKey`).")
                techRow("VideoToolbox",
                        "`CVPixelBuffer → CGImage` dönüşümü (`VTCreateCGImageFromCVPixelBuffer`).")
            }
            
            sectionTitle("Gizlilik")
            Text("""
                 Mirror Top **hiçbir veriyi internete göndermez**, telemetri toplamaz. \
                 Yakalanan tüm kareler yalnızca yerel olarak panele render edilir.
                 """)
        }
    }
    
    // MARK: Kısayollar
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Klavye Kısayolları")
            shortcutRow(keys: ["⌘", "⌥", "T"],
                        title: "Yansıtmayı Aç / Kapat",
                        desc: "Şu anda odakta olan pencereyi yansıtmaya başlar; tekrar basınca kapatır.")
            shortcutRow(keys: ["⌘", "⌥", "I"],
                        title: "Etkileşim Modu",
                        desc: "Yansıtma açıkken; panele tıklayıp yazmayı orijinal pencereye iletir.")
            
            sectionTitle("İpuçları")
            VStack(alignment: .leading, spacing: 10) {
                bullet("Yansıtmadan **önce** istediğiniz pencereyi tıklayıp aktif hâle getirin.")
                bullet("Etkileşim Modu açıkken paneli sürüklemek yerine **başlık çubuğunu** kullanın.")
                bullet("Birden fazla monitör varsa panel açıldığı ekranda kalır; sürükleyerek taşıyabilirsiniz.")
                bullet("Yansıtma kalitesi düşerse hedef pencereyi biraz büyütüp tekrar deneyin.")
            }
        }
    }
    
    // MARK: Künye
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionTitle("Geliştirici")
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "person.fill", label: "Ad Soyad", value: AppInfo.developerName)
                infoRow(icon: "envelope.fill", label: "E-posta",
                        value: AppInfo.developerEmail,
                        link: "mailto:\(AppInfo.developerEmail)")
                infoRow(icon: "link", label: "GitHub",
                        value: AppInfo.developerGithub,
                        link: AppInfo.developerGithub)
            }
            
            sectionTitle("Proje")
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "app.badge", label: "Proje Adı", value: AppInfo.projectName)
                infoRow(icon: "tag.fill", label: "Versiyon",
                        value: "\(AppInfo.version) \(AppInfo.stage)")
                infoRow(icon: "swift", label: "Teknoloji",
                        value: "Swift • SwiftUI • AppKit • ScreenCaptureKit")
                infoRow(icon: "link", label: "GitHub",
                        value: AppInfo.projectGithub,
                        link: AppInfo.projectGithub)
            }
            
            sectionTitle("Geliştirme Sürecinde Kullanılan Yapay Zekâlar")
            VStack(alignment: .leading, spacing: 6) {
                aiRow("Gemini 3 (Hızlı)", role: "Planlama")
                aiRow("Gemini 3.1 Pro (High)", role: "Analiz, Başlangıç Geliştirme")
                aiRow("Claude Opus 4.7", role: "Finalize, Bug Çözümleme, Arayüz Tasarımı")
            }
            
            Text("© \(Calendar.current.component(.year, from: Date())) \(AppInfo.developerName) — Açık kaynak.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 12) {
            Link(destination: URL(string: AppInfo.projectGithub)!) {
                Label("GitHub'da Aç", systemImage: "link")
            }
            .buttonStyle(.bordered)
            
            Link(destination: URL(string: "mailto:\(AppInfo.developerEmail)")!) {
                Label("Geri Bildirim", systemImage: "envelope")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Kapat") { onClose() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.top, 4)
    }
    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .font(.callout)
                .padding(.top, 2)
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
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
            Text(desc)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func shortcutRow(keys: [String], title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    Text(k)
                        .font(.callout.bold().monospaced())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .frame(width: 130, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    
    private func infoRow(icon: String, label: String, value: String, link: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            if let link, let url = URL(string: link) {
                Link(value, destination: url)
                    .font(.callout)
            } else {
                Text(value).font(.callout)
            }
            Spacer()
        }
    }
    
    private func aiRow(_ name: String, role: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            Text(name).font(.callout.bold())
            Text("—").foregroundStyle(.secondary)
            Text(role).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - App Bilgileri

public enum AppInfo {
    public static let projectName     = "Mirror Top"
    public static let version         = "0.0.1"
    public static let stage           = "Alpha"
    public static let projectGithub   = "https://github.com/selcukdinc/mirror-top"
    
    public static let developerName   = "Selçuk DİNÇ"
    public static let developerEmail  = "selcukdinc@devloop.com.tr"
    public static let developerGithub = "https://github.com/selcukdinc"
}

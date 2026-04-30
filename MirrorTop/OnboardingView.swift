import SwiftUI
import AppKit

/// İlk açılışta gösterilen modern izin onboarding penceresi.
/// `PermissionsManager`'ı izleyerek kullanıcı Sistem Ayarları'nda izin verdiği anda
/// kart durumunu canlı günceller ve "Devam Et" butonunu aktive eder.
public struct OnboardingView: View {
    @ObservedObject private var permissions = PermissionsManager.shared
    
    /// İzinler tamamlandığında kapat butonuna basıldığında çağrılır.
    public var onContinue: () -> Void
    /// "?" butonuna basıldığında Hakkında / Yardım penceresini aç.
    public var onShowHelp: (() -> Void)?
    
    public init(onContinue: @escaping () -> Void,
                onShowHelp: (() -> Void)? = nil) {
        self.onContinue = onContinue
        self.onShowHelp = onShowHelp
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "accessibility",
                    title: "Erişilebilirlik",
                    subtitle: "Odaktaki pencereyi okumak ve etkileşim modunda fare/klavye olaylarını yönlendirmek için.",
                    granted: permissions.accessibilityGranted,
                    grantAction: { permissions.requestAccessibility() }
                )
                PermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Ekran Kaydı",
                    subtitle: "Pencereyi yakalayıp şeffaf panele yansıtmak için (ScreenCaptureKit).",
                    granted: permissions.screenRecordingGranted,
                    grantAction: { permissions.requestScreenRecording() }
                )
            }
            .padding(24)
            
            Divider()
            footer
        }
        .frame(width: 520)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            permissions.refresh()
            permissions.startPolling()
        }
        .onDisappear {
            permissions.stopPolling()
        }
    }
    
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)
                Text("Mirror Top'a Hoş Geldiniz")
                    .font(.title2).bold()
                Text("Herhangi bir pencereyi “Always on Top” yapmak için iki izne ihtiyacımız var.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            
            if let onShowHelp {
                Button(action: onShowHelp) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .regular))
                }
                .buttonStyle(.borderless)
                .help("Nasıl çalışır? — Yardım & Hakkında")
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
        }
    }
    
    private var footer: some View {
        HStack {
            if permissions.allGranted {
                Label("Tüm izinler verildi", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Label("İzin bekleniyor…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
            Button {
                onContinue()
            } label: {
                Text(permissions.allGranted ? "Başla" : "Daha Sonra")
                    .frame(minWidth: 90)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(permissions.allGranted ? .accentColor : .gray)
        }
        .padding(20)
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let granted: Bool
    let grantAction: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    StatusBadge(granted: granted)
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: grantAction) {
                Text(granted ? "Ayarları Aç" : "İzin Ver")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(granted ? Color.green.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct StatusBadge: View {
    let granted: Bool
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(granted ? "Verildi" : "Eksik")
        }
        .font(.caption.bold())
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule().fill((granted ? Color.green : Color.orange).opacity(0.18))
        )
        .foregroundStyle(granted ? Color.green : Color.orange)
    }
}

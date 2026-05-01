import SwiftUI
import AppKit

/// İlk açılışta gösterilen modern izin onboarding penceresi.
public struct OnboardingView: View {
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    /// `welcome`: ilk kurulumda gösterilen "Hoş Geldiniz" tonu.
    /// `manage`:  zaten kurulu kullanıcının menüden açtığı sade "İzinleri Yönet" görünümü.
    public enum Mode {
        case welcome
        case manage
    }
    
    public var mode: Mode
    public var onContinue: () -> Void
    public var onShowHelp: (() -> Void)?
    
    public init(mode: Mode = .welcome,
                onContinue: @escaping () -> Void,
                onShowHelp: (() -> Void)? = nil) {
        self.mode = mode
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
                    title: Strings.permAccessibility,
                    subtitle: Strings.permAccessibilityDesc,
                    granted: permissions.accessibilityGranted,
                    grantAction: { permissions.requestAccessibility() }
                )
                PermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: Strings.permScreen,
                    subtitle: Strings.permScreenDesc,
                    granted: permissions.screenRecordingGranted,
                    grantAction: { permissions.requestScreenRecording() }
                )
            }
            .padding(24)
            Divider()
            footer
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .id(settings.language.rawValue)
        .onAppear {
            permissions.refresh()
            permissions.startPolling()
        }
        .onDisappear { permissions.stopPolling() }
    }
    
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                Image(systemName: mode == .welcome ? "rectangle.on.rectangle.angled" : "lock.shield")
                    .font(.system(size: mode == .welcome ? 44 : 36, weight: .light))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)
                Text(mode == .welcome ? Strings.onboardingTitle : Strings.permsManageTitle)
                    .font(.title2).bold()
                Text(mode == .welcome ? Strings.onboardingSubtitle : Strings.permsManageSubtitle)
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
                .help(Strings.helpTooltip)
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
        }
    }
    
    private var footer: some View {
        HStack {
            if permissions.allGranted {
                Label(Strings.permAllGranted, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green).font(.callout)
            } else {
                Label(Strings.permWaiting, systemImage: "hourglass")
                    .foregroundStyle(.secondary).font(.callout)
            }
            Spacer()
            Button { onContinue() } label: {
                Text(closeButtonTitle).frame(minWidth: 90)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(permissions.allGranted ? .accentColor : .gray)
        }
        .padding(20)
    }
    
    private var closeButtonTitle: String {
        switch mode {
        case .welcome:
            return permissions.allGranted ? Strings.start : Strings.later
        case .manage:
            return Strings.done
        }
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
                Text(granted ? Strings.permOpenSettings : Strings.permGrant)
                    .frame(minWidth: 90)
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
            Text(granted ? Strings.permGranted : Strings.permMissing)
        }
        .font(.caption.bold())
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill((granted ? Color.green : Color.orange).opacity(0.18)))
        .foregroundStyle(granted ? Color.green : Color.orange)
    }
}

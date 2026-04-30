import SwiftUI
import AppKit

/// Menü çubuğu (`MenuBarExtra`) içeriği.
public struct MenuBarContent: View {
    @EnvironmentObject private var permissions: PermissionsManager
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isCapturing: Bool = StreamManager.shared.isCapturing
    @State private var interactionMode: Bool = StreamManager.shared.interactionMode
    
    public var showOnboarding: () -> Void
    public var showAbout: () -> Void
    
    public init(showOnboarding: @escaping () -> Void,
                showAbout: @escaping () -> Void) {
        self.showOnboarding = showOnboarding
        self.showAbout = showAbout
    }
    
    public var body: some View {
        Group {
            if !permissions.allGranted {
                Label(Strings.menuPermNeeded, systemImage: "exclamationmark.triangle.fill")
                Button(Strings.menuOpenPerms) { showOnboarding() }
                Divider()
            }
            
            Button(captureLabel) { triggerCapture() }
                .disabled(!permissions.allGranted)
            
            Button(interactionLabel) {
                StreamManager.shared.toggleInteractionMode()
                interactionMode = StreamManager.shared.interactionMode
            }
            .disabled(!StreamManager.shared.isCapturing)
            
            Divider()
            
            Button(Strings.menuManagePerms) { showOnboarding() }
            Button(Strings.menuSettings) { showAbout() }
            Button(Strings.menuHelp) { showAbout() }
            
            Menu(Strings.menuShortcuts) {
                Text("\(SettingsManager.shared.captureShortcut.displayString)   \(Strings.scToggleTitle)")
                Text("\(SettingsManager.shared.interactionShortcut.displayString)   \(Strings.scInteractionTitle)")
            }
            
            Divider()
            
            Button(Strings.menuAbout) { showAbout() }
            Button(Strings.menuQuit) { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .id(settings.language.rawValue)
        .onAppear {
            permissions.refresh()
            isCapturing = StreamManager.shared.isCapturing
            interactionMode = StreamManager.shared.interactionMode
        }
    }
    
    private var captureLabel: String {
        StreamManager.shared.isCapturing ? Strings.menuMirrorStop : Strings.menuMirrorStart
    }
    
    private var interactionLabel: String {
        StreamManager.shared.interactionMode ? Strings.menuInteractionOn : Strings.menuInteractionOff
    }
    
    private func triggerCapture() {
        Task { @MainActor in
            do {
                if let info = try await WindowManager.shared.getFocusedWindow() {
                    try await StreamManager.shared.toggleCapture(windowInfo: info)
                    isCapturing = StreamManager.shared.isCapturing
                }
            } catch {
                print(">>> [MenuBar] HATA: \(error)")
            }
        }
    }
}

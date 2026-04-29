import SwiftUI
import AppKit

/// Menü çubuğu (`MenuBarExtra`) içeriği. Standart `.menu` stilinde ince ve native görünür.
public struct MenuBarContent: View {
    @EnvironmentObject private var permissions: PermissionsManager
    @State private var isCapturing: Bool = StreamManager.shared.isCapturing
    @State private var interactionMode: Bool = StreamManager.shared.interactionMode
    
    public var showOnboarding: () -> Void
    
    public init(showOnboarding: @escaping () -> Void) {
        self.showOnboarding = showOnboarding
    }
    
    public var body: some View {
        Group {
            // Durum bilgisi
            if !permissions.allGranted {
                Label("İzin gerekli", systemImage: "exclamationmark.triangle.fill")
                Button("İzin Ekranını Aç…") { showOnboarding() }
                Divider()
            }
            
            Button(captureLabel) {
                triggerCapture()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(!permissions.allGranted)
            
            Button(interactionLabel) {
                StreamManager.shared.toggleInteractionMode()
                interactionMode = StreamManager.shared.interactionMode
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(!StreamManager.shared.isCapturing)
            
            Divider()
            
            Button("İzinleri Yönet…") { showOnboarding() }
            
            Menu("Yardım") {
                Button("Kısayollar") { }
                    .disabled(true)
                Text("⌘⌥T   Yansıtmayı Aç/Kapat")
                Text("⌘⌥I   Etkileşim Modu")
            }
            
            Divider()
            
            Button("MirrorTop Hakkında") { showAbout() }
            Button("Çıkış") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        // Menü her açıldığında durumu yenile
        .onAppear {
            permissions.refresh()
            isCapturing = StreamManager.shared.isCapturing
            interactionMode = StreamManager.shared.interactionMode
        }
    }
    
    private var captureLabel: String {
        StreamManager.shared.isCapturing ? "Yansıtmayı Durdur" : "Odaktaki Pencereyi Yansıt"
    }
    
    private var interactionLabel: String {
        StreamManager.shared.interactionMode ? "Etkileşim Modu: AÇIK" : "Etkileşim Modu: KAPALI"
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
    
    private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MirrorTop",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(
                string: "Açık kaynak — github.com/selcukdinc/MirrorTop",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}

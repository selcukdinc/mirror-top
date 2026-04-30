import SwiftUI
import AppKit

/// Tıklanınca bir sonraki tuş kombinasyonunu yakalayan SwiftUI kontrolü.
/// `binding`'e yakaladığı `Shortcut`'u yazar.
public struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut
    var defaultShortcut: Shortcut
    
    @State private var isRecording: Bool = false
    @State private var monitor: Any?
    
    public init(shortcut: Binding<Shortcut>, defaultValue: Shortcut) {
        _shortcut = shortcut
        self.defaultShortcut = defaultValue
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                        .foregroundStyle(isRecording ? .red : .primary)
                    Text(isRecording ? L10n.tr("Tuş kombinasyonunu basın…", "Press a key combination…")
                                     : shortcut.displayString)
                        .font(.callout.monospaced().bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minWidth: 160, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.red : Color.secondary.opacity(0.3),
                                      lineWidth: isRecording ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            
            Button {
                shortcut = defaultShortcut
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("Varsayılana sıfırla", "Reset to default"))
        }
        .onDisappear { stopRecording() }
    }
    
    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }
    
    private func startRecording() {
        stopRecording()
        isRecording = true
        // Local monitor: sadece bu uygulama key alırken yakalar (yeterli — kullanıcı butona tıkladığı için zaten odakta).
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // flagsChanged → modifier'ları izlemek istersek burada handle ederdik. Sadece keyDown'a bakıyoruz.
            guard event.type == .keyDown else { return event }
            
            // Escape → iptal
            if event.keyCode == UInt16(0x35) {
                stopRecording()
                return nil
            }
            
            if let captured = Shortcut.from(event: event) {
                shortcut = captured
                stopRecording()
                return nil // event'i tüket
            } else {
                // Modifier yok — kullanıcı uyarılmış oluyor (UI'da hala "press combination" görüyor).
                NSSound.beep()
                return event
            }
        }
    }
    
    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}

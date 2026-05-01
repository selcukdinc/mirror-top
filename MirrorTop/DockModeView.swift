import SwiftUI
import AppKit

/// Dock-mode: yakın zamanda PiP'lenmiş tüm pencerelerin grid önizlemesi.
/// Pinch-zoom ile yoğunluk değişir (2 → 5 sütun).
public struct DockModeView: View {
    @ObservedObject private var registry = MirrorRegistry.shared
    @State private var columns: Int = 3
    @State private var pinchAccumulator: CGFloat = 1.0
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
            footer
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 480)
        .background(VisualEffectBackground())
    }
    
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Strings.dockModeTitle)
                .font(.title2).bold()
            Spacer()
            Text(Strings.dockHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if registry.snapshots.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
                Text(Strings.dockModeEmpty)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 14), count: columns)
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(registry.snapshots) { snap in
                        DockCell(snapshot: snap)
                    }
                }
                .padding(.vertical, 4)
            }
            .gesture(magnifyGesture)
        }
    }
    
    private var footer: some View {
        HStack {
            Stepper(value: $columns, in: 2...6) {
                Text("\(columns) × \(columns)").font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 160)
            Spacer()
        }
    }
    
    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / pinchAccumulator
                pinchAccumulator = value
                if delta < 0.85 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        columns = min(columns + 1, 6)
                    }
                } else if delta > 1.18 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        columns = max(columns - 1, 2)
                    }
                }
            }
            .onEnded { _ in pinchAccumulator = 1.0 }
    }
}

private struct DockCell: View {
    let snapshot: MirrorRegistry.Snapshot
    @State private var isHovering = false
    
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
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16.0/10.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private var overlayButtons: some View {
        HStack(spacing: 6) {
            actionButton(systemName: "rectangle.on.rectangle", help: Strings.dockHover_focus) {
                // Tek başına öne getir: aktif PiP'i (varsa) yeniden aç.
                // MVP: sadece pencereyi orderFront yapıyoruz, çoklu stream gelecek sürümde.
                StreamManager.shared.bringActivePanelToFront()
            }
            actionButton(systemName: "xmark.circle.fill", help: Strings.dockHover_remove) {
                MirrorRegistry.shared.remove(snapshot)
            }
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

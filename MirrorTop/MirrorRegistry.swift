import Foundation
import AppKit
import Combine

/// Yakın zamanda PiP'lenmiş pencerelerin küçük "snapshot" kayıtlarını tutan registry.
///
/// Şu anda MirrorTop tek aktif `StreamManager` ile çalışıyor; yine de Dock-mode grid'i
/// için kullanıcının son N penceresini hatırlamak ve her birinin son karesini önizleme
/// olarak göstermek istiyoruz. Bu sınıf bir "geçmiş + canlı snapshot" cache'idir.
///
/// Aktif PiP varsa `activeSnapshot` doludur ve `StreamManager` her ~30 karede bir
/// `updateActiveSnapshot(_:)` ile günceller.
@MainActor
public final class MirrorRegistry: ObservableObject {
    public static let shared = MirrorRegistry()
    
    public struct Snapshot: Identifiable {
        public let id: String          // bundleID + titleHash
        public let bundleID: String
        public var appName: String
        public var title: String
        public var image: CGImage?     // son bilinen kare (küçük preview için)
        public var savedFrame: NSRect? // son bilinen panel frame'i
        public var lastSeen: Date
        public var isActive: Bool      // şu an PiP aktif mi
    }
    
    /// LRU sırasında: 0 = en yeni.
    @Published public private(set) var snapshots: [Snapshot] = []
    
    private init() {}
    
    /// Yeni PiP başladığında çağrılır.
    public func registerActive(bundleID: String, appName: String, title: String, frame: NSRect) {
        let id = idFor(bundleID: bundleID, title: title)
        // Önceki aktif kaydı pasifleştir.
        for i in snapshots.indices { snapshots[i].isActive = false }
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            var s = snapshots.remove(at: idx)
            s.isActive = true
            s.lastSeen = Date()
            s.savedFrame = frame
            s.title = title
            s.appName = appName
            snapshots.insert(s, at: 0)
        } else {
            let s = Snapshot(id: id,
                             bundleID: bundleID,
                             appName: appName,
                             title: title,
                             image: nil,
                             savedFrame: frame,
                             lastSeen: Date(),
                             isActive: true)
            snapshots.insert(s, at: 0)
        }
        trimIfNeeded()
    }
    
    /// PiP kapandığında çağrılır.
    public func markInactive(bundleID: String, title: String) {
        let id = idFor(bundleID: bundleID, title: title)
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            snapshots[idx].isActive = false
            snapshots[idx].lastSeen = Date()
        }
    }
    
    /// Aktif PiP'in son karesini güncelle (throttle StreamManager tarafında yapılır).
    public func updateActiveSnapshot(image: CGImage) {
        guard let idx = snapshots.firstIndex(where: { $0.isActive }) else { return }
        snapshots[idx].image = image
    }
    
    /// Kullanıcı bir snapshot'ı listeden kaldırmak isterse.
    public func remove(_ snapshot: Snapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
    }
    
    public func clearAll() {
        snapshots.removeAll()
    }
    
    private func idFor(bundleID: String, title: String) -> String {
        let hash = String(format: "%08x", title.hashValue & 0xFFFFFFFF)
        return "\(bundleID).\(hash)"
    }
    
    private func trimIfNeeded() {
        let maxItems = 16
        if snapshots.count > maxItems {
            snapshots = Array(snapshots.prefix(maxItems))
        }
    }
}

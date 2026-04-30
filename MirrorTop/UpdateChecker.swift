import Foundation
import AppKit
import Combine

// MARK: - Update Result

public struct UpdateInfo: Equatable, Sendable {
    public let latestVersion: String      // örn. "0.0.2"
    public let currentVersion: String     // örn. "0.0.1"
    public let releaseURL: URL
    public let publishedAt: Date?
    public let body: String?
    
    public var isNewer: Bool {
        UpdateChecker.compare(latestVersion, isGreaterThan: currentVersion)
    }
}

public enum UpdateCheckResult: Sendable {
    case upToDate(current: String)
    case updateAvailable(UpdateInfo)
    case failed(String)
}

// MARK: - GitHub Release Modeli

private struct GHRelease: Decodable {
    let tag_name: String
    let name: String?
    let html_url: String
    let body: String?
    let published_at: String?
    let prerelease: Bool
    let draft: Bool
}

// MARK: - Checker

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()
    
    /// Owner / Repo. README ve About'taki linklerle uyumlu.
    public let repoOwner = "selcukdinc"
    public let repoName  = "mirror-top"
    
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var lastResult: UpdateCheckResult?
    
    private init() {}
    
    /// Mevcut sürüm — `AppInfo.version`.
    public var currentVersion: String { AppInfo.version }
    
    private var releasesURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }
    
    /// Manuel güncelleme kontrolü.
    @discardableResult
    public func check() async -> UpdateCheckResult {
        isChecking = true
        defer {
            isChecking = false
            SettingsManager.shared.lastUpdateCheck = Date()
        }
        
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MirrorTop/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                let r = UpdateCheckResult.failed("invalid response")
                lastResult = r
                return r
            }
            
            // 404 → henüz hiç release yok. Bu hata değil, sadece "no release".
            if http.statusCode == 404 {
                let r = UpdateCheckResult.upToDate(current: currentVersion)
                lastResult = r
                return r
            }
            
            guard (200...299).contains(http.statusCode) else {
                let r = UpdateCheckResult.failed("HTTP \(http.statusCode)")
                lastResult = r
                return r
            }
            
            let decoder = JSONDecoder()
            let release = try decoder.decode(GHRelease.self, from: data)
            
            // Draft veya prerelease'leri yoksay.
            guard !release.draft, !release.prerelease else {
                let r = UpdateCheckResult.upToDate(current: currentVersion)
                lastResult = r
                return r
            }
            
            let latest = Self.normalizeVersion(release.tag_name)
            let publishedDate: Date? = {
                guard let p = release.published_at else { return nil }
                let f = ISO8601DateFormatter()
                return f.date(from: p)
            }()
            
            let info = UpdateInfo(
                latestVersion: latest,
                currentVersion: currentVersion,
                releaseURL: URL(string: release.html_url) ?? releasesURL,
                publishedAt: publishedDate,
                body: release.body
            )
            
            let result: UpdateCheckResult = info.isNewer
                ? .updateAvailable(info)
                : .upToDate(current: currentVersion)
            lastResult = result
            return result
        } catch {
            let r = UpdateCheckResult.failed(error.localizedDescription)
            lastResult = r
            return r
        }
    }
    
    /// Açılışta otomatik kontrol — yalnızca kullanıcı `autoUpdateCheck`'i açtıysa çalışır.
    public func checkOnLaunchIfEnabled() {
        guard SettingsManager.shared.autoUpdateCheck else { return }
        Task { _ = await check() }
    }
    
    public func openLatestReleasePage() {
        if case .updateAvailable(let info) = lastResult {
            NSWorkspace.shared.open(info.releaseURL)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!)
        }
    }
    
    // MARK: - Helpers
    
    /// "v0.0.2", "0.0.2-alpha" gibi tag'leri "0.0.2"e normalize eder.
    public static func normalizeVersion(_ raw: String) -> String {
        var v = raw
        if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
        if let dashIdx = v.firstIndex(of: "-") {
            v = String(v[..<dashIdx])
        }
        return v.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Semver karşılaştırması (sadece sayısal segmentler).
    public static func compare(_ lhs: String, isGreaterThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxLen = max(lhsParts.count, rhsParts.count)
        for i in 0..<maxLen {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }
}

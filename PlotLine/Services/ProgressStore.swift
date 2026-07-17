import SwiftUI

/// Per-episode watch progress, ported from the web app's `progress.ts`
/// (`pl_progress` → `showId → { s{S}e{E}: { watched, skipped, frac } }`).
@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    struct EpState: Codable, Hashable {
        var watched: Bool = false
        var skipped: Bool = false
        var frac: Double = 0    // 0..1 runtime fraction
        var watchedAt: Double?  // epoch ms
    }

    private let lsKey = "pl_progress"
    /// showId -> "s{S}e{E}" -> state
    private(set) var shows: [String: [String: EpState]] = [:]

    private init() { load() }

    static func epKey(_ s: Int, _ e: Int) -> String { "s\(s)e\(e)" }

    func show(_ showId: Int) -> [String: EpState] { shows[String(showId)] ?? [:] }

    func state(_ showId: Int, _ s: Int, _ e: Int) -> EpState {
        show(showId)[Self.epKey(s, e)] ?? EpState()
    }

    /// Number of episodes marked watched (used for progress bars/badges).
    func watchedCount(_ showId: Int) -> Int {
        show(showId).values.filter { $0.watched }.count
    }

    func setWatched(_ showId: Int, _ s: Int, _ e: Int, _ watched: Bool) {
        var map = shows[String(showId)] ?? [:]
        var st = map[Self.epKey(s, e)] ?? EpState()
        st.watched = watched
        st.watchedAt = watched ? Date().timeIntervalSince1970 * 1000 : nil
        if watched { st.frac = 1 } else { st.frac = 0 }
        map[Self.epKey(s, e)] = st
        shows[String(showId)] = map
        persist()
    }

    func setFrac(_ showId: Int, _ s: Int, _ e: Int, _ frac: Double) {
        var map = shows[String(showId)] ?? [:]
        var st = map[Self.epKey(s, e)] ?? EpState()
        st.frac = min(max(frac, 0), 1)
        st.watched = st.frac >= 0.98
        map[Self.epKey(s, e)] = st
        shows[String(showId)] = map
        persist()
    }

    func clearShow(_ showId: Int) {
        shows[String(showId)] = nil
        persist()
    }

    private func load() {
        // Stored as a JSON string under `pl_progress` (web-compatible shape).
        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [String: EpState]].self, from: data) {
            shows = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(shows),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    func rehydrate() { load() }
}

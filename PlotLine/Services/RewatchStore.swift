import SwiftUI

/// Rewatch counts — ported from the web `rewatch.ts` (`pl_rewatch` → `media:id` → count).
@Observable
final class RewatchStore {
    static let shared = RewatchStore()

    private let lsKey = "pl_rewatch"
    private(set) var counts: [String: Int] = [:]

    private init() { load() }

    private func key(_ media: MediaKind, _ id: Int) -> String { "\(media.rawValue):\(id)" }

    func count(_ media: MediaKind, _ id: Int) -> Int { counts[key(media, id)] ?? 0 }

    /// Increment the rewatch count for a title.
    func increment(_ media: MediaKind, _ id: Int) {
        counts[key(media, id), default: 0] += 1
        persist()
    }

    private func load() {
        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            counts = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(counts), let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    func rehydrate() { load() }
}

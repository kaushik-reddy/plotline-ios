import SwiftUI

/// Per-episode user comments — ported from the web `pl_comments` store. Persisted as a
/// web-compatible JSON string (`showId:s{S}e{E}` → list of `{id,text,at}`).
@Observable
final class CommentsStore {
    static let shared = CommentsStore()

    struct Comment: Codable, Identifiable, Hashable {
        let id: String
        let text: String
        let at: Double  // epoch ms
    }

    private let lsKey = "pl_comments"
    private(set) var map: [String: [Comment]] = [:]

    private init() { load() }

    static func epKey(_ showId: Int, _ s: Int, _ e: Int) -> String { "\(showId):s\(s)e\(e)" }

    func comments(_ showId: Int, _ s: Int, _ e: Int) -> [Comment] {
        (map[Self.epKey(showId, s, e)] ?? []).sorted { $0.at > $1.at }
    }

    func count(_ showId: Int, _ s: Int, _ e: Int) -> Int {
        map[Self.epKey(showId, s, e)]?.count ?? 0
    }

    func add(_ showId: Int, _ s: Int, _ e: Int, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let c = Comment(id: UUID().uuidString, text: t, at: Date().timeIntervalSince1970 * 1000)
        map[Self.epKey(showId, s, e), default: []].append(c)
        persist()
    }

    private func load() {
        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [Comment]].self, from: data) {
            map = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(map), let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    func rehydrate() { load() }
}

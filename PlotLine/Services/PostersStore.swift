import SwiftUI

/// Poster/backdrop overrides — ported from the web `posters.ts` (`pl_posters` →
/// `media:id:slot` → path). Lets you pick a different poster/backdrop for a title.
@Observable
final class PostersStore {
    static let shared = PostersStore()

    private let lsKey = "pl_posters"
    private(set) var map: [String: String] = [:]

    private init() { load() }

    private func key(_ media: MediaKind, _ id: Int, _ slot: String) -> String { "\(media.rawValue):\(id):\(slot)" }

    func override(_ media: MediaKind, _ id: Int, _ slot: String) -> String? { map[key(media, id, slot)] }

    func set(_ media: MediaKind, _ id: Int, _ slot: String, _ path: String) {
        map[key(media, id, slot)] = path
        persist()
    }

    func reset(_ media: MediaKind, _ id: Int, _ slot: String) {
        map[key(media, id, slot)] = nil
        persist()
    }

    private func load() {
        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
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

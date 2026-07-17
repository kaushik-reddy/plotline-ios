import SwiftUI

/// The single source of truth for a title's status across every screen (Binge,
/// Calendar, Continue Watching, …). Ported from the web app's `library.ts`, backed
/// by `UserDefaults` under the `pl_lib_overrides` key so the same seed + override
/// model applies and cross-device sync stays compatible.
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    /// Seed spread across statuses so every screen has content out of the box.
    /// User edits are stored as overrides on top and always win.
    private static let seed: [LibEntry] = [
        LibEntry(media: .tv, id: "100088", status: .watching),   // The Last of Us
        LibEntry(media: .tv, id: "95396", status: .watching),    // Severance
        LibEntry(media: .movie, id: "872585", status: .watching), // Oppenheimer
        LibEntry(media: .tv, id: "94997", status: .caughtup),    // House of the Dragon
        LibEntry(media: .tv, id: "125988", status: .scheduled, scheduledAt: schedAt(1, 20, 30), scheduledSub: "S1 E1"), // Silo
        LibEntry(media: .movie, id: "693134", status: .scheduled, scheduledAt: schedAt(3, 19, 0), scheduledSub: "Movie night"), // Dune 2
        LibEntry(media: .tv, id: "136315", status: .watchlist),  // The Bear
        LibEntry(media: .movie, id: "157336", status: .watchlist), // Interstellar
        LibEntry(media: .tv, id: "1396", status: .completed),    // Breaking Bad
        LibEntry(media: .movie, id: "27205", status: .completed), // Inception
    ]

    private static func schedAt(_ offsetDays: Int, _ h: Int, _ m: Int) -> Double {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: offsetDays, to: Date()) ?? Date()
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        comps.hour = h; comps.minute = m
        let d = cal.date(from: comps) ?? Date()
        return d.timeIntervalSince1970 * 1000
    }

    private let lsKey = "pl_lib_overrides"
    /// null override (removed) is represented by an entry absent from `entries` but
    /// present in `removed`.
    private var removed: Set<String> = []
    private(set) var entries: [LibEntry] = []

    private init() {
        load()
    }

    // MARK: Reads

    func entry(_ media: MediaKind, _ id: String) -> LibEntry? {
        entries.first { $0.media == media && $0.id == id }
    }

    func entry(_ media: MediaKind, _ id: Int) -> LibEntry? { entry(media, String(id)) }

    func count(_ status: LibStatus) -> Int { entries.filter { $0.status == status }.count }

    // MARK: Mutations

    func setStatus(_ media: MediaKind, _ id: String, _ status: LibStatus, scheduledAt: Double? = nil, scheduledSub: String? = nil) {
        removed.remove(media.rawValue + ":" + id)
        if let idx = entries.firstIndex(where: { $0.media == media && $0.id == id }) {
            entries[idx].status = status
            if let scheduledAt { entries[idx].scheduledAt = scheduledAt }
            if let scheduledSub { entries[idx].scheduledSub = scheduledSub }
        } else {
            entries.append(LibEntry(media: media, id: id, status: status, scheduledAt: scheduledAt, scheduledSub: scheduledSub))
        }
        persist()
    }

    func clear(_ media: MediaKind, _ id: String) {
        entries.removeAll { $0.media == media && $0.id == id }
        removed.insert(media.rawValue + ":" + id)
        persist()
    }

    // MARK: Persistence (overrides on top of seed)
    //
    // Stored under `pl_lib_overrides` as a JSON *string* in the same shape as the web
    // app: `{ "media:id": { …LibEntry… } | null }` (null = removed). This keeps
    // cross-device sync fully compatible, so your existing web library loads on the phone.

    private func load() {
        var map: [String: LibEntry] = [:]
        for e in Self.seed { map[e.key] = e }
        removed = []

        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (k, v) in obj {
                if v is NSNull {
                    map[k] = nil
                    removed.insert(k)
                } else if let d = v as? [String: Any], let entry = Self.entry(from: d) {
                    map[entry.key] = entry
                }
            }
        }
        entries = Array(map.values).sorted { $0.key < $1.key }
    }

    private static func entry(from d: [String: Any]) -> LibEntry? {
        guard let mediaRaw = d["media"] as? String, let media = MediaKind(rawValue: mediaRaw),
              let statusRaw = d["status"] as? String, let status = LibStatus(rawValue: statusRaw)
        else { return nil }
        let id = (d["id"] as? String) ?? String(describing: d["id"] ?? "")
        return LibEntry(media: media, id: id, status: status,
                        scheduledAt: d["scheduledAt"] as? Double,
                        scheduledSub: d["scheduledSub"] as? String)
    }

    private func persist() {
        // Overrides = diff vs seed, in web JSON shape.
        var seedMap: [String: LibEntry] = [:]
        for e in Self.seed { seedMap[e.key] = e }
        var obj: [String: Any] = [:]
        for e in entries where seedMap[e.key] != e {
            var d: [String: Any] = ["media": e.media.rawValue, "id": e.id, "status": e.status.rawValue]
            if let s = e.scheduledAt { d["scheduledAt"] = s }
            if let s = e.scheduledSub { d["scheduledSub"] = s }
            obj[e.key] = d
        }
        for r in removed where seedMap[r] != nil { obj[r] = NSNull() }
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    /// Re-read from disk (e.g. after a cross-device sync pull).
    func rehydrate() { load() }
}

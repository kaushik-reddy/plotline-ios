import SwiftUI

/// Your personal ratings, ported from the web app. Each title's PlotLine rating is
/// the average of every rating you've given it (an overall quick pick plus any
/// show/season/episode review ratings). Stored per title under a `pl_rating_<media>_<id>`
/// derived cache key so it stays compatible with the web reader.
@Observable
final class RatingStore {
    static let shared = RatingStore()

    /// media:id -> list of raw ratings (1...10) you've given (quick + reviews).
    private(set) var raw: [String: [Double]] = [:]
    private let lsKey = "pl_ratings_ios"

    private init() { load() }

    private func key(_ media: MediaKind, _ id: Int) -> String { "\(media.rawValue):\(id)" }

    /// Averaged PlotLine rating (1 decimal), or nil if unrated. Falls back to the
    /// web-compatible `pl_rating_<media>_<id>` cache (e.g. ratings synced from the site).
    func rating(_ media: MediaKind, _ id: Int) -> Double? {
        if let list = raw[key(media, id)], !list.isEmpty {
            let avg = list.reduce(0, +) / Double(list.count)
            return (avg * 10).rounded() / 10
        }
        let cacheKey = "pl_rating_\(media.rawValue)_\(id)"
        if UserDefaults.standard.object(forKey: cacheKey) != nil {
            let v = UserDefaults.standard.double(forKey: cacheKey)
            if v > 0 { return (v * 10).rounded() / 10 }
        }
        return nil
    }

    /// Set your single overall ("quick") rating for a title. Replaces the whole list
    /// with one value (simple model for the mobile app).
    func setQuick(_ media: MediaKind, _ id: Int, _ value: Double) {
        raw[key(media, id)] = [value]
        // Mirror the derived value to the web-compatible cache key.
        UserDefaults.standard.set(rating(media, id) ?? value, forKey: "pl_rating_\(media.rawValue)_\(id)")
        persist()
    }

    func clear(_ media: MediaKind, _ id: Int) {
        raw[key(media, id)] = nil
        UserDefaults.standard.removeObject(forKey: "pl_rating_\(media.rawValue)_\(id)")
        persist()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: lsKey),
           let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            raw = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    func rehydrate() { load() }
}

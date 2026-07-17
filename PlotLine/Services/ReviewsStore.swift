import SwiftUI

/// A written review — rating + text (with lightweight markdown) + optional spoiler flag + scope.
struct Review: Codable, Identifiable, Hashable {
    let id: String
    let media: String
    let tmdbId: Int
    let rating: Double
    let text: String
    let scope: String   // "Full show" · "Movie" · "Season N" · "S# E#"
    let spoiler: Bool
    let at: Double       // epoch ms
}

/// Your reviews, per title. Feeds the Detail reviews sheet and (via ratings) the PlotLine score.
@Observable
final class ReviewsStore {
    static let shared = ReviewsStore()

    private let lsKey = "pl_reviews_ios"
    private(set) var byTitle: [String: [Review]] = [:]

    private init() { load() }

    private func key(_ media: MediaKind, _ id: Int) -> String { "\(media.rawValue):\(id)" }

    func reviews(_ media: MediaKind, _ id: Int) -> [Review] {
        (byTitle[key(media, id)] ?? []).sorted { $0.at > $1.at }
    }

    func count(_ media: MediaKind, _ id: Int) -> Int { byTitle[key(media, id)]?.count ?? 0 }

    func add(_ media: MediaKind, _ id: Int, rating: Double, text: String, scope: String, spoiler: Bool) {
        let review = Review(id: UUID().uuidString, media: media.rawValue, tmdbId: id, rating: rating,
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines), scope: scope,
                            spoiler: spoiler, at: Date().timeIntervalSince1970 * 1000)
        byTitle[key(media, id), default: []].append(review)
        // Mirror the rating so the PlotLine rating/score picks it up.
        RatingStore.shared.setQuick(media, id, rating)
        persist()
    }

    private func load() {
        if let str = UserDefaults.standard.string(forKey: lsKey),
           let data = str.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [Review]].self, from: data) {
            byTitle = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(byTitle), let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: lsKey)
        }
        SyncService.shared.markDirty()
    }

    func rehydrate() { load() }
}

import SwiftUI

/// A social persona (seeded author or you). Avatars reuse the DiceBear-seed monogram.
struct Persona: Identifiable, Hashable {
    let name: String
    let handle: String
    let seed: String
    var id: String { handle }
}

/// A feed post — a review/rating/comment on a movie, series, season or episode.
struct FeedPost: Identifiable, Hashable {
    let id: String
    let persona: Persona
    let media: MediaKind
    let tmdbId: Int
    let titleName: String
    let scopeLabel: String   // "Movie" · "Full series" · "Season 2" · "Episode · S2 E3"
    let rating: Double        // out of 10
    let text: String
    let when: String          // relative label, e.g. "12m"
    let tag: String           // "#Severance"
    let inFollowing: Bool
}

/// A reply on a post (one level of threading in the native rebuild).
struct FeedReply: Identifiable, Hashable {
    let id: String
    let postId: String
    let persona: Persona
    let text: String
    let when: String
}

enum FeedMode: String, CaseIterable { case following = "Following", global = "Global" }

/// The social feed — ported from the web `Feed.tsx`: seeded personas + posts, likes, replies,
/// a Following↔Global toggle and #title tag filtering. Likes and your replies persist locally.
@Observable
final class FeedStore {
    static let shared = FeedStore()

    let me = Persona(name: "You", handle: "you", seed: ProfileStore_Avatar.shared.seed)

    // Seeded authors.
    private static let nova = Persona(name: "Nova Watches", handle: "novawatches", seed: "Nova")
    private static let rahul = Persona(name: "Reel Rahul", handle: "reelrahul", seed: "Rahul")
    private static let bug = Persona(name: "Binge Bug", handle: "bingebug", seed: "BingeBug")
    private static let geek = Persona(name: "CineGeek", handle: "cinegeek", seed: "CineGeek")
    private static let frame = Persona(name: "Frame by Frame", handle: "framebyframe", seed: "Frame")

    private(set) var posts: [FeedPost] = [
        FeedPost(id: "p1", persona: Self.nova, media: .tv, tmdbId: 95396, titleName: "Severance",
                 scopeLabel: "Episode · S2 E3", rating: 9, text: "The restraint in this episode is unreal. Every quiet frame feels like it is hiding a second story.",
                 when: "12m", tag: "#Severance", inFollowing: true),
        FeedPost(id: "p2", persona: Self.rahul, media: .movie, tmdbId: 872585, titleName: "Oppenheimer",
                 scopeLabel: "Movie", rating: 8, text: "A huge film that still finds room for guilt, ego and consequence. The sound design deserves its own rating.",
                 when: "38m", tag: "#Oppenheimer", inFollowing: true),
        FeedPost(id: "p3", persona: Self.bug, media: .tv, tmdbId: 125988, titleName: "Silo",
                 scopeLabel: "Episode · S1 E6", rating: 9, text: "That final reveal changed how I read every conversation leading up to it. Proper slow-burn payoff.",
                 when: "1h", tag: "#Silo", inFollowing: true),
        FeedPost(id: "p4", persona: Self.nova, media: .tv, tmdbId: 100088, titleName: "The Last of Us",
                 scopeLabel: "Full series", rating: 9, text: "A brutal adaptation that understands the quiet moments are what make the violence matter.",
                 when: "5h", tag: "#TheLastOfUs", inFollowing: true),
        FeedPost(id: "p5", persona: Self.rahul, media: .movie, tmdbId: 693134, titleName: "Dune: Part Two",
                 scopeLabel: "Movie", rating: 9, text: "Scale, rhythm, and confidence. The arena sequence alone is worth seeing on the largest screen possible.",
                 when: "8h", tag: "#DunePartTwo", inFollowing: false),
        FeedPost(id: "p6", persona: Self.geek, media: .tv, tmdbId: 136315, titleName: "The Bear",
                 scopeLabel: "Full series", rating: 8, text: "Chaotic, tender, exhausting — somehow exactly like being in a real kitchen with people you love.",
                 when: "1d", tag: "#TheBear", inFollowing: false),
        FeedPost(id: "p7", persona: Self.frame, media: .tv, tmdbId: 94997, titleName: "House of the Dragon",
                 scopeLabel: "Season 2", rating: 8, text: "The politics finally click into place. Every alliance feels one bad night away from collapse.",
                 when: "1d", tag: "#HouseOfTheDragon", inFollowing: false),
    ]

    private var seededReplies: [String: [FeedReply]] = [
        "p1": [
            FeedReply(id: "r1", postId: "p1", persona: Self.rahul, text: "The blocking in the hallway scene was perfect.", when: "8m"),
        ],
        "p2": [
            FeedReply(id: "r2", postId: "p2", persona: Self.geek, text: "The sound dropping out before the test is still chilling.", when: "25m"),
        ],
        "p3": [
            FeedReply(id: "r3", postId: "p3", persona: Self.frame, text: "Silo rewards patience better than almost anything airing now.", when: "42m"),
        ],
    ]

    var mode: FeedMode = .following
    var tagFilter: String? = nil

    private let likeKey = "pl_feed_likes_ios"
    private let replyKey = "pl_feed_replies_ios"
    private var liked: Set<String> = []
    private var userReplies: [String: [FeedReply]] = [:]
    private var likeBase: [String: Int] = ["p1": 18, "p2": 31, "p3": 24, "p4": 37, "p5": 42, "p6": 29, "p7": 21]

    private init() {
        if let arr = UserDefaults.standard.array(forKey: likeKey) as? [String] { liked = Set(arr) }
        loadReplies()
    }

    var visiblePosts: [FeedPost] {
        posts.filter { post in
            (mode == .global || post.inFollowing) && (tagFilter == nil || post.tag == tagFilter)
        }
    }

    /// All tags present (for the filter chips).
    var tags: [String] { Array(Set(posts.map(\.tag))).sorted() }

    func replies(for postId: String) -> [FeedReply] {
        (seededReplies[postId] ?? []) + (userReplies[postId] ?? [])
    }

    func isLiked(_ id: String) -> Bool { liked.contains(id) }
    func likeCount(_ id: String) -> Int { (likeBase[id] ?? 0) + (liked.contains(id) ? 1 : 0) }

    func toggleLike(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
        UserDefaults.standard.set(Array(liked), forKey: likeKey)
    }

    func addReply(to postId: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let reply = FeedReply(id: UUID().uuidString, postId: postId, persona: me, text: t, when: "now")
        userReplies[postId, default: []].append(reply)
        saveReplies()
    }

    // MARK: Persistence for user replies

    private struct StoredReply: Codable { let id, postId, name, handle, seed, text, when: String }

    private func saveReplies() {
        let flat = userReplies.values.flatMap { $0 }.map {
            StoredReply(id: $0.id, postId: $0.postId, name: $0.persona.name, handle: $0.persona.handle, seed: $0.persona.seed, text: $0.text, when: $0.when)
        }
        if let data = try? JSONEncoder().encode(flat) { UserDefaults.standard.set(data, forKey: replyKey) }
    }

    private func loadReplies() {
        guard let data = UserDefaults.standard.data(forKey: replyKey),
              let flat = try? JSONDecoder().decode([StoredReply].self, from: data) else { return }
        for s in flat {
            let r = FeedReply(id: s.id, postId: s.postId, persona: Persona(name: s.name, handle: s.handle, seed: s.seed), text: s.text, when: s.when)
            userReplies[s.postId, default: []].append(r)
        }
    }
}

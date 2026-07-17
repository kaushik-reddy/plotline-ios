import Foundation

/// Media kind, matching the web app's `Media = 'movie' | 'tv'`.
enum MediaKind: String, Codable, Hashable {
    case movie
    case tv

    var label: String { self == .movie ? "Movie" : "Series" }
}

/// A lightweight title as returned by list/search/discover endpoints. Movie and TV
/// fields are merged (TMDB uses `title`/`release_date` for movies and
/// `name`/`first_air_date` for TV), so a single model covers both.
struct TitleItem: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let name: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let voteAverage: Double?
    let releaseDate: String?
    let firstAirDate: String?
    let originalLanguage: String?
    // Present on /trending & /search/multi results; absent on typed rails.
    let mediaTypeRaw: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case originalLanguage = "original_language"
        case mediaTypeRaw = "media_type"
    }

    /// Best display name across movie/TV shapes.
    var displayTitle: String { title ?? name ?? "Untitled" }

    /// Release year (4 chars of the relevant date).
    var year: String? {
        let d = releaseDate ?? firstAirDate
        guard let d, d.count >= 4 else { return nil }
        return String(d.prefix(4))
    }

    /// Resolve the media kind: prefer the explicit `media_type`, else infer from
    /// which date field is present (TV shows carry `first_air_date`).
    func kind(default fallback: MediaKind = .movie) -> MediaKind {
        if let m = mediaTypeRaw, let k = MediaKind(rawValue: m) { return k }
        if name != nil && title == nil { return .tv }
        if firstAirDate != nil && releaseDate == nil { return .tv }
        return fallback
    }
}

/// A page of list results.
struct PagedResults: Codable {
    let results: [TitleItem]
    let page: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case results, page
        case totalPages = "total_pages"
    }
}

struct Genre: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct GenreList: Codable {
    let genres: [Genre]
}

/// Full title detail (movie or TV), including appended sub-resources.
struct TitleDetail: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let releaseDate: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let status: String?
    let inProduction: Bool?
    let originalLanguage: String?
    let genres: [Genre]?
    let seasons: [SeasonSummary]?
    let networks: [NamedRef]?
    let originCountry: [String]?
    let credits: Credits?
    let videos: VideoList?
    let recommendations: PagedResults?
    let similar: PagedResults?
    let externalIds: ExternalIds?
    let lastEpisodeToAir: EpisodeBrief?
    let nextEpisodeToAir: EpisodeBrief?
    let images: TitleImages?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, tagline, runtime, status, genres, seasons, networks, credits, videos, recommendations, similar, images
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case episodeRunTime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case inProduction = "in_production"
        case originalLanguage = "original_language"
        case originCountry = "origin_country"
        case externalIds = "external_ids"
        case lastEpisodeToAir = "last_episode_to_air"
        case nextEpisodeToAir = "next_episode_to_air"
    }

    var displayTitle: String { title ?? name ?? "Untitled" }
    var year: String? {
        let d = releaseDate ?? firstAirDate
        guard let d, d.count >= 4 else { return nil }
        return String(d.prefix(4))
    }
}

struct NamedRef: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct ExternalIds: Codable {
    let imdbId: String?
    enum CodingKeys: String, CodingKey { case imdbId = "imdb_id" }
}

struct SeasonSummary: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int?
    let posterPath: String?
    let airDate: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
    }
}

struct SeasonDetail: Codable {
    let episodes: [Episode]
}

struct Episode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let airDate: String?
    let runtime: Int?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
}

struct EpisodeBrief: Codable, Hashable {
    let name: String?
    let overview: String?
    let episodeNumber: Int?
    let seasonNumber: Int?
    let stillPath: String?
    let airDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case name, overview
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
}

struct Video: Codable, Identifiable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
}

struct TitleImages: Codable {
    let posters: [ImageRef]?
    let backdrops: [ImageRef]?
}

struct ImageRef: Codable, Identifiable, Hashable {
    let filePath: String
    var id: String { filePath }
    enum CodingKeys: String, CodingKey { case filePath = "file_path" }
}

struct Credits: Codable {
    let cast: [CastMember]?
}

struct CastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

struct VideoList: Codable {
    let results: [Video]
}

import SwiftUI

/// Home — the app's dashboard. Mirrors the web Home: a Continue Watching rail on top,
/// an "Up Next" planned rail, and trending / in-theaters discovery rails below.
struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ProgressStore.self) private var progress
    @State private var model = HomeModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                greeting

                if !model.continueWatching.isEmpty {
                    ContinueWatchingRail(items: model.continueWatching)
                }
                if !model.upNext.isEmpty {
                    PosterRail(title: "Up Next", kicker: "Planned", items: model.upNext)
                }
                if model.trending.isEmpty {
                    railSkeleton
                } else {
                    PosterRail(title: "Trending This Week", kicker: "Discover", items: model.trending)
                }
                if !model.nowPlaying.isEmpty {
                    PosterRail(title: "In Theaters", items: model.nowPlaying, media: .movie)
                }
                if !model.popularTv.isEmpty {
                    PosterRail(title: "Popular Series", items: model.popularTv, media: .tv)
                }
            }
            .padding(.vertical, 16)
        }
        .background(PageBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(library: library, progress: progress) }
        .refreshable { await model.load(library: library, progress: progress, fresh: true) }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.greetingText)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("What are we watching today?")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
    }

    private var railSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Trending This Week", kicker: "Discover")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Shimmer()
                            .frame(width: 128, height: 128 / Theme.posterAspect)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// A watching entry with resolved artwork + a 0…1 progress value.
struct CWItem: Identifiable {
    let ref: TitleRef
    let title: String
    let backdropPath: String?
    let posterPath: String?
    let subtitle: String
    let progress: Double
    var id: String { "\(ref.media.rawValue):\(ref.id)" }
}

/// Landscape Continue Watching cards with an orange progress bar (matches the web CW rail).
struct ContinueWatchingRail: View {
    let items: [CWItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Continue Watching", kicker: "Jump back in")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: item.ref) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottom) {
                                    RemoteImage(path: item.backdropPath ?? item.posterPath, size: "w780")
                                        .frame(width: 260, height: 146)
                                        .clipped()
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Rectangle().fill(.white.opacity(0.2))
                                            Rectangle().fill(Theme.orange)
                                                .frame(width: geo.size.width * item.progress)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))

                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
                            .frame(width: 260, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Loads and holds Home content.
@Observable
final class HomeModel {
    var continueWatching: [CWItem] = []
    var upNext: [TitleItem] = []
    var trending: [TitleItem] = []
    var nowPlaying: [TitleItem] = []
    var popularTv: [TitleItem] = []
    private var loaded = false

    var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night watching"
        }
    }

    @MainActor
    func load(library: LibraryStore, progress: ProgressStore, fresh: Bool = false) async {
        if loaded && !fresh { return }
        loaded = true
        let svc = TMDBService.shared

        async let trendingR = svc.get("/trending/all/week", as: PagedResults.self)
        async let nowR = svc.get("/movie/now_playing", as: PagedResults.self)
        async let tvR = svc.get("/tv/popular", as: PagedResults.self)

        trending = (await trendingR)?.results.filter { $0.posterPath != nil } ?? []
        nowPlaying = (await nowR)?.results.filter { $0.posterPath != nil } ?? []
        popularTv = (await tvR)?.results.filter { $0.posterPath != nil } ?? []

        await loadPersonalRails(library: library, progress: progress)
    }

    @MainActor
    private func loadPersonalRails(library: LibraryStore, progress: ProgressStore) async {
        let svc = TMDBService.shared
        var cw: [CWItem] = []
        var planned: [TitleItem] = []

        for entry in library.entries {
            switch entry.status {
            case .watching:
                guard let idInt = Int(entry.id) else { continue }
                if let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) {
                    let prog: Double
                    var sub = d.displayTitle
                    if entry.media == .tv, let total = d.numberOfEpisodes, total > 0 {
                        let watched = progress.watchedCount(idInt)
                        prog = min(Double(watched) / Double(total), 1)
                        sub = "\(watched)/\(total) episodes"
                    } else {
                        prog = 0.4
                        sub = "Resume"
                    }
                    cw.append(CWItem(ref: TitleRef(media: entry.media, id: idInt),
                                     title: d.displayTitle,
                                     backdropPath: d.backdropPath,
                                     posterPath: d.posterPath,
                                     subtitle: sub, progress: prog))
                }
            case .watchlist, .scheduled:
                if let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self),
                   let idInt = Int(entry.id) {
                    planned.append(TitleItem(id: idInt, title: d.title, name: d.name,
                                             posterPath: d.posterPath, backdropPath: d.backdropPath,
                                             overview: d.overview, voteAverage: d.voteAverage,
                                             releaseDate: d.releaseDate, firstAirDate: d.firstAirDate,
                                             originalLanguage: d.originalLanguage,
                                             mediaTypeRaw: entry.media.rawValue))
                }
            default:
                break
            }
        }
        continueWatching = cw
        upNext = planned
    }
}

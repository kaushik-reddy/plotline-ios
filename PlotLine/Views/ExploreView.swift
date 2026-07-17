import SwiftUI

/// Explore — search + filters + browse rails, a native port of the web Explore page:
/// a trending spotlight hero, grouped rails (Browse / By Language / By Country / By Genre),
/// and Type / Genre / Sort filters that switch to a discover grid.
struct ExploreView: View {
    @State private var model = ExploreModel()
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchField
                controls

                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    resultsGrid(model.searchResults, empty: "No matches", loading: model.searching)
                } else if model.filtersActive {
                    resultsGrid(model.filterResults, empty: "No titles", loading: model.filtering)
                } else {
                    if let hero = model.hero { heroCard(hero) }
                    rails
                }
            }
            .padding(.vertical, 12)
        }
        .background(PageBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadRails() }
        .task(id: query) {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await model.search(query)
        }
    }

    // MARK: Search + controls

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField("Search movies & series", text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .foregroundStyle(Theme.text)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var controls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(ExploreModel.MediaFilter.allCases, id: \.self) { m in
                        Button(m.label) { model.mediaFilter = m; Task { await model.applyFilters() } }
                    }
                } label: { filterChip(model.mediaFilter.label, active: model.mediaFilter != .all) }

                Menu {
                    Button("All genres") { model.genreId = nil; Task { await model.applyFilters() } }
                    ForEach(model.genres) { g in
                        Button(g.name) { model.genreId = g.id; Task { await model.applyFilters() } }
                    }
                } label: { filterChip(model.genreName ?? "Genre", active: model.genreId != nil) }

                Menu {
                    ForEach(ExploreModel.SortOption.allCases, id: \.self) { s in
                        Button(s.label) { model.sort = s; Task { await model.applyFilters() } }
                    }
                } label: { filterChip(model.sort.label, active: model.sort != .popularity) }

                if model.filtersActive {
                    Button {
                        model.reset(); Task { await model.applyFilters() }
                    } label: {
                        Text("Reset").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.orange)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ label: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.system(size: 12, weight: .semibold))
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(active ? .black : Theme.text)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(active ? Theme.orange : Theme.panel, in: Capsule())
        .overlay(Capsule().stroke(active ? .clear : Theme.line, lineWidth: 1))
    }

    // MARK: Hero

    private func heroCard(_ item: TitleItem) -> some View {
        NavigationLink(value: TitleRef(media: item.kind(), id: item.id)) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(path: item.backdropPath ?? item.posterPath, size: "w780")
                    .frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRENDING NOW").font(.system(size: 10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.orange)
                    Text(item.displayTitle).font(.system(size: 22, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    if let o = item.overview, !o.isEmpty {
                        Text(o).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: Rails / grid

    private var rails: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(ExploreModel.groupOrder, id: \.self) { group in
                let groupRails = model.rails.filter { $0.group == group && !$0.items.isEmpty }
                if !groupRails.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(group.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(1.8)
                            .foregroundStyle(Theme.faint).padding(.horizontal, 16)
                        ForEach(groupRails) { rail in
                            PosterRail(title: rail.title, items: rail.items, media: rail.media)
                        }
                    }
                }
            }
            if model.rails.allSatisfy({ $0.items.isEmpty }) {
                ForEach(0..<3, id: \.self) { _ in railSkeleton }
            }
        }
    }

    private func resultsGrid(_ items: [TitleItem], empty: String, loading: Bool) -> some View {
        Group {
            if loading {
                HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }.padding(.top, 40)
            } else if items.isEmpty {
                Text(empty).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], alignment: .leading, spacing: 16) {
                    ForEach(items) { PosterCard(item: $0, width: 108) }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var railSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Shimmer().frame(width: 160, height: 18).clipShape(Capsule()).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Shimmer().frame(width: 128, height: 128 / Theme.posterAspect).clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct ExploreRail: Identifiable {
    let id = UUID()
    let group: String
    let title: String
    let media: MediaKind?
    var items: [TitleItem]
}

@Observable
final class ExploreModel {
    enum MediaFilter: String, CaseIterable {
        case all, movie, tv
        var label: String { self == .all ? "All" : (self == .movie ? "Movies" : "Series") }
    }
    enum SortOption: String, CaseIterable {
        case popularity, topRated, newest
        var label: String { self == .popularity ? "Popularity" : (self == .topRated ? "Top Rated" : "Newest") }
    }

    static let groupOrder = ["Browse", "By Language", "By Country", "By Genre"]

    var rails: [ExploreRail] = []
    var genres: [Genre] = []
    var hero: TitleItem?

    var searchResults: [TitleItem] = []
    var searching = false
    var filterResults: [TitleItem] = []
    var filtering = false

    var mediaFilter: MediaFilter = .all
    var genreId: Int?
    var sort: SortOption = .popularity

    var filtersActive: Bool { genreId != nil || sort != .popularity || mediaFilter != .all }
    var genreName: String? { genreId.flatMap { id in genres.first { $0.id == id }?.name } }

    private var railsLoaded = false

    private struct Spec { let group, title, path: String; let q: String?; let media: MediaKind? }
    private let specs: [Spec] = [
        Spec(group: "Browse", title: "Trending", path: "/trending/all/week", q: nil, media: nil),
        Spec(group: "Browse", title: "Popular Movies", path: "/movie/popular", q: nil, media: .movie),
        Spec(group: "Browse", title: "Popular Series", path: "/tv/popular", q: nil, media: .tv),
        Spec(group: "Browse", title: "Top Rated Movies", path: "/movie/top_rated", q: nil, media: .movie),
        Spec(group: "Browse", title: "On The Air", path: "/tv/on_the_air", q: nil, media: .tv),
        Spec(group: "Browse", title: "Upcoming Movies", path: "/movie/upcoming", q: nil, media: .movie),
        Spec(group: "By Language", title: "Hindi Cinema", path: "/discover/movie", q: "with_original_language=hi&sort_by=popularity.desc&vote_count.gte=40", media: .movie),
        Spec(group: "By Language", title: "Korean Series", path: "/discover/tv", q: "with_original_language=ko&sort_by=popularity.desc", media: .tv),
        Spec(group: "By Language", title: "Anime", path: "/discover/tv", q: "with_original_language=ja&with_genres=16&sort_by=popularity.desc", media: .tv),
        Spec(group: "By Language", title: "Spanish Movies", path: "/discover/movie", q: "with_original_language=es&sort_by=popularity.desc&vote_count.gte=40", media: .movie),
        Spec(group: "By Country", title: "From India", path: "/discover/tv", q: "with_origin_country=IN&sort_by=popularity.desc", media: .tv),
        Spec(group: "By Country", title: "From Korea", path: "/discover/movie", q: "with_original_language=ko&sort_by=popularity.desc&vote_count.gte=20", media: .movie),
        Spec(group: "By Country", title: "From Japan", path: "/discover/tv", q: "with_origin_country=JP&sort_by=popularity.desc", media: .tv),
        Spec(group: "By Genre", title: "Action", path: "/discover/movie", q: "with_genres=28&sort_by=popularity.desc&vote_count.gte=100", media: .movie),
        Spec(group: "By Genre", title: "Comedy", path: "/discover/movie", q: "with_genres=35&sort_by=popularity.desc&vote_count.gte=100", media: .movie),
        Spec(group: "By Genre", title: "Horror", path: "/discover/movie", q: "with_genres=27&sort_by=popularity.desc&vote_count.gte=60", media: .movie),
        Spec(group: "By Genre", title: "Sci-Fi", path: "/discover/movie", q: "with_genres=878&sort_by=popularity.desc&vote_count.gte=100", media: .movie),
    ]

    @MainActor
    func loadRails() async {
        if railsLoaded { return }
        railsLoaded = true
        let svc = TMDBService.shared

        async let genreMovie = svc.get("/genre/movie/list", as: GenreList.self)
        async let genreTv = svc.get("/genre/tv/list", as: GenreList.self)
        var seen = Set<Int>()
        var merged: [Genre] = []
        for g in ((await genreMovie)?.genres ?? []) + ((await genreTv)?.genres ?? []) where !seen.contains(g.id) {
            seen.insert(g.id); merged.append(g)
        }
        genres = merged.sorted { $0.name < $1.name }

        var out: [ExploreRail] = []
        for spec in specs {
            let page = await svc.get(spec.path, q: spec.q, as: PagedResults.self)
            let items = (page?.results ?? []).filter { $0.posterPath != nil }
            out.append(ExploreRail(group: spec.group, title: spec.title, media: spec.media, items: items))
            if hero == nil, spec.title == "Trending" { hero = items.first }
        }
        rails = out
    }

    @MainActor
    func search(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; searching = false; return }
        searching = true
        let page = await TMDBService.shared.get("/search/multi", q: "query=\(q)", as: PagedResults.self)
        searchResults = (page?.results ?? []).filter { ($0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv") && $0.posterPath != nil }
        searching = false
    }

    @MainActor
    func applyFilters() async {
        guard filtersActive else { filterResults = []; return }
        filtering = true
        let svc = TMDBService.shared
        let sortParam: String
        switch sort {
        case .popularity: sortParam = "popularity.desc"
        case .topRated: sortParam = "vote_average.desc&vote_count.gte=200"
        case .newest: sortParam = "primary_release_date.desc"
        }
        func q(_ tv: Bool) -> String {
            var parts = ["sort_by=\(tv && sort == .newest ? "first_air_date.desc" : sortParam)"]
            if let g = genreId { parts.append("with_genres=\(g)") }
            return parts.joined(separator: "&")
        }
        var results: [TitleItem] = []
        if mediaFilter != .tv {
            if let p = await svc.get("/discover/movie", q: q(false), as: PagedResults.self) {
                results += p.results.filter { $0.posterPath != nil }.map { tag($0, .movie) }
            }
        }
        if mediaFilter != .movie {
            if let p = await svc.get("/discover/tv", q: q(true), as: PagedResults.self) {
                results += p.results.filter { $0.posterPath != nil }.map { tag($0, .tv) }
            }
        }
        // Sort merged by rating/popularity approximation for a stable grid.
        filterResults = results.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        filtering = false
    }

    private func tag(_ item: TitleItem, _ media: MediaKind) -> TitleItem {
        TitleItem(id: item.id, title: item.title, name: item.name, posterPath: item.posterPath,
                  backdropPath: item.backdropPath, overview: item.overview, voteAverage: item.voteAverage,
                  releaseDate: item.releaseDate, firstAirDate: item.firstAirDate,
                  originalLanguage: item.originalLanguage, mediaTypeRaw: media.rawValue)
    }

    func reset() {
        mediaFilter = .all; genreId = nil; sort = .popularity
    }
}

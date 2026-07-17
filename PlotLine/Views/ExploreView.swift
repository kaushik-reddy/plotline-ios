import SwiftUI

/// Explore — search + browse rails. Mirrors the web Explore page: a search field that
/// queries `/search/multi`, and a set of discovery rails when the query is empty.
struct ExploreView: View {
    @State private var model = ExploreModel()
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchField

                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField("Search movies & series", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.text)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var searchResults: some View {
        Group {
            if model.searching {
                HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }
                    .padding(.top, 40)
            } else if model.results.isEmpty {
                Text("No matches")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(model.results) { item in
                        PosterCard(item: item, width: 108)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var rails: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(model.rails) { rail in
                if rail.items.isEmpty {
                    EmptyView()
                } else {
                    PosterRail(title: rail.title, items: rail.items, media: rail.media)
                }
            }
            if model.rails.allSatisfy({ $0.items.isEmpty }) {
                ForEach(0..<3, id: \.self) { _ in railSkeleton }
            }
        }
    }

    private var railSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Shimmer().frame(width: 160, height: 18).clipShape(Capsule()).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Shimmer().frame(width: 128, height: 128 / Theme.posterAspect)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct ExploreRail: Identifiable {
    let id = UUID()
    let title: String
    let media: MediaKind?
    var items: [TitleItem]
}

@Observable
final class ExploreModel {
    var rails: [ExploreRail] = []
    var results: [TitleItem] = []
    var searching = false
    private var railsLoaded = false

    private struct RailSpec { let title: String; let path: String; let media: MediaKind? }
    private let specs: [RailSpec] = [
        RailSpec(title: "Trending", path: "/trending/all/week", media: nil),
        RailSpec(title: "Popular Movies", path: "/movie/popular", media: .movie),
        RailSpec(title: "Popular Series", path: "/tv/popular", media: .tv),
        RailSpec(title: "Top Rated Movies", path: "/movie/top_rated", media: .movie),
        RailSpec(title: "On The Air", path: "/tv/on_the_air", media: .tv),
        RailSpec(title: "Upcoming Movies", path: "/movie/upcoming", media: .movie),
    ]

    @MainActor
    func loadRails() async {
        if railsLoaded { return }
        railsLoaded = true
        let svc = TMDBService.shared
        var out: [ExploreRail] = []
        for spec in specs {
            let page = await svc.get(spec.path, as: PagedResults.self)
            let items = (page?.results ?? []).filter { $0.posterPath != nil }
            out.append(ExploreRail(title: spec.title, media: spec.media, items: items))
        }
        rails = out
    }

    @MainActor
    func search(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; searching = false; return }
        searching = true
        let svc = TMDBService.shared
        let page = await svc.get("/search/multi", q: "query=\(q)", as: PagedResults.self)
        results = (page?.results ?? [])
            .filter { ($0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv") && $0.posterPath != nil }
        searching = false
    }
}

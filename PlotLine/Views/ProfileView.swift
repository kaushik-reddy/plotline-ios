import SwiftUI

/// Profile — identity, library stats, cross-device sync and region settings. Mirrors the
/// web Profile/Settings: a header, a status breakdown, the sync card, and a country picker.
struct ProfileView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(RegionStore.self) private var region
    @Environment(SyncService.self) private var sync
    @Environment(ProfileStore_Avatar.self) private var avatar
    @Environment(ProgressStore.self) private var progress
    @Environment(RatingStore.self) private var ratings

    @State private var model = ProfileModel()
    @State private var connectCode = ""
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                allTimeCard
                scoreAndGenres
                ratingsHistogram
                if !model.watching.isEmpty { rail("Currently Watching", model.watching) }
                if !model.favorites.isEmpty { rail("Favorites", model.favorites) }
                if !model.upNext.isEmpty { rail("Up Next", model.upNext) }
                breakdown
                syncCard
                regionCard
                Color.clear.frame(height: 20)
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(library: library, progress: progress, ratings: ratings) }
    }

    // MARK: Hero + stats

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(path: model.coverBackdrop, size: "w780")
                    .frame(height: 130).frame(maxWidth: .infinity).clipped()
                    .overlay(LinearGradient(colors: [.clear, Theme.bg], startPoint: .top, endPoint: .bottom))
                HStack(spacing: 12) {
                    AvatarView(seed: avatar.seed, size: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(avatar.name).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                        Text("PlotLine member").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))

            HStack(spacing: 10) {
                stat("\(library.entries.count)", "Tracked")
                stat("\(library.count(.watching))", "Watching")
                stat("\(library.count(.completed))", "Completed")
            }
        }
    }

    private var allTimeCard: some View {
        panel {
            SectionHeader(title: "All Time", kicker: "Stats")
            HStack(spacing: 10) {
                statBox("\(model.movies)", "Movies")
                statBox("\(model.shows)", "Shows")
                statBox("\(model.episodes)", "Episodes")
                statBox(watchTime, "Watch time")
            }
        }
    }

    private var watchTime: String {
        let h = model.watchMinutes / 60
        return h >= 24 ? "\(h / 24)d \(h % 24)h" : "\(h)h"
    }

    private var scoreAndGenres: some View {
        panel {
            SectionHeader(title: "PlotLine Score", kicker: "Insights")
            Text("\(model.score)").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.orange)
            if !model.topGenres.isEmpty {
                Text("TOP GENRES").font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Theme.faint).padding(.top, 4)
                let maxG = model.topGenres.map(\.count).max() ?? 1
                ForEach(model.topGenres, id: \.name) { g in
                    HStack(spacing: 8) {
                        Text(g.name).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.panelRaised)
                                Capsule().fill(Theme.orange).frame(width: max(4, geo.size.width * CGFloat(g.count) / CGFloat(maxG)))
                            }
                        }
                        .frame(height: 8)
                        Text("\(g.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 24)
                    }
                }
            }
        }
    }

    private var ratingsHistogram: some View {
        panel {
            SectionHeader(title: "Your Ratings", kicker: "Histogram")
            let maxH = model.ratingHistogram.max() ?? 1
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    VStack(spacing: 4) {
                        Rectangle().fill(Theme.green)
                            .frame(height: max(3, CGFloat(model.ratingHistogram[i]) / CGFloat(max(maxH, 1)) * 80))
                        Text("\(i + 1)").font(.system(size: 9)).foregroundStyle(Theme.faint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
    }

    private func rail(_ title: String, _ items: [TitleItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { PosterCard(item: $0, width: 100) }
                }
            }
        }
    }

    private func panel<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private func statBox(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.text)
            Text(l).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Library", kicker: "Breakdown")
            ForEach(LibStatus.order) { s in
                let c = library.count(s)
                if c > 0 {
                    HStack {
                        Circle().fill(s.color).frame(width: 9, height: 9)
                        Text(s.label).font(.system(size: 14)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(c)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Sync

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cross-device Sync", kicker: "Settings")

            if let code = sync.code {
                Text("Synced under code")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                HStack {
                    Text(code).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(Theme.orange)
                    Spacer()
                    syncStatusView
                }
                HStack(spacing: 10) {
                    actionButton("Sync now", filled: true) { Task { working = true; await sync.pull(); await sync.push(); working = false } }
                    actionButton("Stop syncing", filled: false) { sync.disconnect() }
                }
            } else {
                Text("Enter the same code on another device — or on the website — to mirror your whole library, progress and ratings.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                actionButton("Enable sync", filled: true) {
                    Task { working = true; _ = await sync.connect(sync.generateCode()); working = false }
                }
                HStack(spacing: 8) {
                    TextField("Have a code? Enter it", text: $connectCode)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .foregroundStyle(Theme.text)
                        .padding(10)
                        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                    Button("Link") {
                        Task { working = true; _ = await sync.connect(connectCode); connectCode = ""; working = false }
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                    .disabled(connectCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private var syncStatusView: some View {
        Group {
            switch sync.status {
            case .syncing: HStack(spacing: 5) { ProgressView().controlSize(.mini).tint(Theme.orange); Text("Syncing") }
            case .synced: HStack(spacing: 5) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green); Text("Synced") }
            case .offline: HStack(spacing: 5) { Image(systemName: "wifi.slash").foregroundStyle(Theme.amber); Text("Offline") }
            case .error: HStack(spacing: 5) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.red); Text("Error") }
            case .idle: EmptyView()
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.muted)
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(filled ? Theme.orange : Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(filled ? .clear : Theme.line, lineWidth: 1))
                .foregroundStyle(filled ? .black : Theme.text)
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    // MARK: Region

    private var regionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Region", kicker: "Settings")
            Picker("Country", selection: Binding(get: { region.code }, set: { region.setCountry($0) })) {
                ForEach(RegionStore.countries) { c in
                    Text(c.name).tag(c.code)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.orange)
            Text("Timezone: \(region.country.tz)")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }
}

/// Loads library metadata and aggregates the Profile insights (stats, top genres, ratings
/// histogram, PlotLine score, and the poster rails).
@Observable
final class ProfileModel {
    var coverBackdrop: String?
    var movies = 0
    var shows = 0
    var episodes = 0
    var watchMinutes = 0
    var topGenres: [(name: String, count: Int)] = []
    var ratingHistogram: [Int] = Array(repeating: 0, count: 10)
    var watching: [TitleItem] = []
    var favorites: [TitleItem] = []
    var upNext: [TitleItem] = []
    var score = 0
    private var loaded = false

    @MainActor
    func load(library: LibraryStore, progress: ProgressStore, ratings: RatingStore) async {
        if loaded { return }
        loaded = true
        let svc = TMDBService.shared
        var genreCounts: [String: Int] = [:]
        var movieC = 0, showC = 0, epC = 0
        var watchingItems: [TitleItem] = [], favItems: [TitleItem] = [], upItems: [TitleItem] = []

        for entry in library.entries {
            guard let idInt = Int(entry.id),
                  let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) else { continue }
            let item = TitleItem(id: idInt, title: d.title, name: d.name, posterPath: d.posterPath,
                                 backdropPath: d.backdropPath, overview: d.overview, voteAverage: d.voteAverage,
                                 releaseDate: d.releaseDate, firstAirDate: d.firstAirDate,
                                 originalLanguage: d.originalLanguage, mediaTypeRaw: entry.media.rawValue)
            if entry.media == .movie { movieC += 1 } else { showC += 1; epC += progress.watchedCount(idInt) }
            for g in d.genres ?? [] { genreCounts[g.name, default: 0] += 1 }
            if coverBackdrop == nil, d.backdropPath != nil, entry.status == .watching || entry.status == .completed {
                coverBackdrop = d.backdropPath
            }
            switch entry.status {
            case .watching: watchingItems.append(item)
            case .completed: favItems.append(item)
            case .watchlist, .scheduled: upItems.append(item)
            default: break
            }
        }

        movies = movieC; shows = showC; episodes = epC
        watchMinutes = epC * 42 + movieC * 115
        topGenres = genreCounts.sorted { $0.value > $1.value }.prefix(5).map { (name: $0.key, count: $0.value) }
        watching = watchingItems; favorites = favItems; upNext = upItems

        var hist = Array(repeating: 0, count: 10)
        for (_, list) in ratings.raw where !list.isEmpty {
            let avg = list.reduce(0, +) / Double(list.count)
            let bucket = min(max(Int(avg.rounded()) - 1, 0), 9)
            hist[bucket] += 1
        }
        ratingHistogram = hist
        score = ratings.raw.count * 10 + library.entries.count * 2 + epC
    }
}

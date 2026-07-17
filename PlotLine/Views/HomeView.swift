import SwiftUI

/// Home — the dashboard. Native port of the web Home: Continue Watching, an "Up Next" planned
/// rail with live countdowns, the social Feed, and the Movie & TV News reader.
struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ProgressStore.self) private var progress
    @Environment(\.openURL) private var openURL
    @State private var model = HomeModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greeting

                if !model.continueWatching.isEmpty {
                    ContinueWatchingRail(items: model.continueWatching)
                }
                if !model.nextPlanned.isEmpty {
                    nextPlannedSection
                }

                FeedView()

                if !model.news.isEmpty {
                    newsSection
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
            Text(model.greetingText).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.text)
            Text("What are we watching today?").font(.system(size: 14)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Next Planned

    private var nextPlannedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Up Next", kicker: "Planned").padding(.horizontal, 16)
            VStack(spacing: 10) {
                ForEach(model.nextPlanned) { item in
                    NavigationLink(value: item.ref) {
                        HStack(spacing: 12) {
                            RemoteImage(path: item.posterPath, size: "w300")
                                .frame(width: 96, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(item.subtitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(item.accent).lineLimit(1)
                            }
                            Spacer()
                            CountdownText(target: item.date)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.green)
                        }
                        .padding(10)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: News

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Latest in Movies & TV", kicker: "News").padding(.horizontal, 16)
            VStack(spacing: 14) {
                if let hero = model.news.first {
                    newsHero(hero)
                }
                ForEach(model.news.dropFirst().prefix(12)) { item in
                    newsRow(item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func newsHero(_ item: NewsItem) -> some View {
        Button { open(item) } label: {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: item.image ?? "")) { phase in
                    if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                    else { Theme.panelRaised }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                if let source = item.source {
                    Text(source.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Theme.orange)
                }
                Text(item.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text).lineLimit(3)
            }
        }
        .buttonStyle(.plain)
    }

    private func newsRow(_ item: NewsItem) -> some View {
        Button { open(item) } label: {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: URL(string: item.image ?? "")) { phase in
                    if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                    else { Theme.panelRaised }
                }
                .frame(width: 96, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                VStack(alignment: .leading, spacing: 4) {
                    if let source = item.source {
                        Text(source.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Theme.orange)
                    }
                    Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(3)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func open(_ item: NewsItem) {
        if let url = URL(string: item.link) { openURL(url) }
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

/// A planned/upcoming item with a target date for the live countdown.
struct PlannedItem: Identifiable {
    let ref: TitleRef
    let title: String
    let posterPath: String?
    let subtitle: String
    let date: Date
    let accent: Color
    var id: String { "\(ref.media.rawValue):\(ref.id)" }
}

/// Landscape Continue Watching cards with an orange progress bar.
struct ContinueWatchingRail: View {
    let items: [CWItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Continue Watching", kicker: "Jump back in").padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: item.ref) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottom) {
                                    RemoteImage(path: item.backdropPath ?? item.posterPath, size: "w780")
                                        .frame(width: 260, height: 146).clipped()
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Rectangle().fill(.white.opacity(0.2))
                                            Rectangle().fill(Theme.orange).frame(width: geo.size.width * item.progress)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                                Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(item.subtitle).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
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

@Observable
final class HomeModel {
    var continueWatching: [CWItem] = []
    var nextPlanned: [PlannedItem] = []
    var news: [NewsItem] = []
    private var loaded = false

    var greetingText: String {
        switch Calendar.current.component(.hour, from: Date()) {
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
        async let newsR = NewsService.fetch()
        await loadPersonal(library: library, progress: progress)
        news = await newsR
    }

    @MainActor
    private func loadPersonal(library: LibraryStore, progress: ProgressStore) async {
        let svc = TMDBService.shared
        let isoDay = DateFormatter(); isoDay.dateFormat = "yyyy-MM-dd"
        let now = Date()
        var cw: [CWItem] = []
        var planned: [PlannedItem] = []

        for entry in library.entries {
            guard let idInt = Int(entry.id) else { continue }
            if entry.status == .watching {
                if let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) {
                    let prog: Double
                    var sub = "Resume"
                    if entry.media == .tv, let total = d.numberOfEpisodes, total > 0 {
                        let watched = progress.watchedCount(idInt)
                        prog = min(Double(watched) / Double(total), 1)
                        sub = "\(watched)/\(total) episodes"
                    } else { prog = 0.4 }
                    cw.append(CWItem(ref: TitleRef(media: entry.media, id: idInt), title: d.displayTitle,
                                     backdropPath: d.backdropPath, posterPath: d.posterPath, subtitle: sub, progress: prog))
                }
            }
            if entry.status == .scheduled, let at = entry.scheduledAt {
                if let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) {
                    planned.append(PlannedItem(ref: TitleRef(media: entry.media, id: idInt), title: d.displayTitle,
                                               posterPath: d.backdropPath ?? d.posterPath,
                                               subtitle: entry.scheduledSub ?? "Scheduled", date: Date(timeIntervalSince1970: at / 1000), accent: Theme.orange))
                }
            } else if entry.media == .tv, entry.status == .watching || entry.status == .caughtup {
                if let d = await svc.get("/tv/\(entry.id)", as: TitleDetail.self),
                   let next = d.nextEpisodeToAir, let ds = next.airDate, let date = isoDay.date(from: ds), date >= Calendar.current.startOfDay(for: now) {
                    planned.append(PlannedItem(ref: TitleRef(media: .tv, id: idInt), title: d.displayTitle,
                                               posterPath: next.stillPath ?? d.backdropPath,
                                               subtitle: "New episode · S\(next.seasonNumber ?? 0) E\(next.episodeNumber ?? 0)", date: date, accent: Theme.blue))
                }
            }
        }
        continueWatching = cw
        nextPlanned = planned.sorted { $0.date < $1.date }
    }
}

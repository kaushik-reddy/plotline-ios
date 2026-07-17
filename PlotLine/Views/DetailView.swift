import SwiftUI

/// Title detail page (movie or TV) — mirrors the web `/title/:media/:id`. Cinematic hero
/// with backdrop/poster/logo-style title, meta + status, ratings row with your PlotLine
/// rating, an action column (Add Status / Rate), plus cast, seasons and recommendations.
struct DetailView: View {
    let media: MediaKind
    let id: Int

    @Environment(LibraryStore.self) private var library
    @Environment(RatingStore.self) private var ratings
    @Environment(ProgressStore.self) private var progress
    @Environment(LiveActivityManager.self) private var live
    @Environment(\.dismiss) private var dismiss

    @State private var model = DetailModel()
    @State private var showStatusSheet = false
    @State private var showRateSheet = false
    @State private var seasonSheet: SeasonSummary?
    @State private var videoKey: VideoKey?
    @State private var posters = PostersStore.shared
    @State private var rewatch = RewatchStore.shared
    @State private var reviews = ReviewsStore.shared
    @State private var showPosterSheet = false
    @State private var showReviewsSheet = false

    private var entry: LibEntry? { library.entry(media, id) }

    var body: some View {
        ScrollView {
            if let d = model.detail {
                VStack(alignment: .leading, spacing: 22) {
                    hero(d)
                    actionRow
                    secondaryActions(d)
                    liveActivityButton(d)
                    ratingsRow(d)
                    if let overview = d.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                    }
                    if media == .tv {
                        EpisodeTimelineView(detail: d)
                    }
                    if media == .tv, let seasons = d.seasons?.filter({ $0.seasonNumber > 0 }), !seasons.isEmpty {
                        seasonsRail(d, seasons)
                    }
                    CommunityStatusView(media: media, id: id, voteCount: d.voteCount ?? 0)
                    if media == .tv, let seasons = d.seasons?.filter({ $0.seasonNumber > 0 }), !seasons.isEmpty {
                        EpisodeRatingMap(showId: id, seasons: seasons)
                    }
                    if let videos = d.videos?.results.filter({ $0.site == "YouTube" }), !videos.isEmpty {
                        videosRail(videos)
                    }
                    if let cast = d.credits?.cast, !cast.isEmpty {
                        castRail(cast)
                    }
                    if let recs = d.recommendations?.results.filter({ $0.posterPath != nil }), !recs.isEmpty {
                        PosterRail(title: "Recommendations", items: recs)
                    }
                    if let sim = d.similar?.results.filter({ $0.posterPath != nil }), !sim.isEmpty {
                        PosterRail(title: "Similar", items: sim)
                    }
                    Color.clear.frame(height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                heroSkeleton
            }
        }
        .background(PageBackground())
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { backButton }
        .task { await model.load(media: media, id: id) }
        .sheet(isPresented: $showStatusSheet) { statusSheet }
        .sheet(isPresented: $showRateSheet) { rateSheet }
        .sheet(item: $seasonSheet) { season in
            SeasonPlaygroundView(showId: id, showName: model.detail?.displayTitle ?? "", season: season, posterFallback: model.detail?.posterPath)
        }
        .sheet(item: $videoKey) { v in
            VideoSheet(key: v.key)
        }
        .sheet(isPresented: $showPosterSheet) {
            PosterPickerSheet(media: media, id: id,
                              posters: model.detail?.images?.posters?.map(\.filePath) ?? [model.detail?.posterPath].compactMap { $0 },
                              backdrops: model.detail?.images?.backdrops?.map(\.filePath) ?? [model.detail?.backdropPath].compactMap { $0 })
        }
        .sheet(isPresented: $showReviewsSheet) {
            ReviewSheet(media: media, id: id, isTv: media == .tv)
        }
    }

    // MARK: Hero

    private func hero(_ d: TitleDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(path: posters.override(media, id, "backdrop") ?? d.backdropPath ?? d.posterPath, size: "w780")
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.4), Theme.bg],
                                   startPoint: .top, endPoint: .bottom)
                )
            HStack(alignment: .bottom, spacing: 14) {
                Button { showPosterSheet = true } label: {
                    RemoteImage(path: posters.override(media, id, "poster") ?? d.posterPath, size: "w342")
                        .frame(width: 96, height: 96 / Theme.posterAspect)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.lineStrong, lineWidth: 1))
                        .shadow(color: .black.opacity(0.6), radius: 10, y: 6)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    Text(d.displayTitle)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    Text(metaLine(d))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    if rewatch.count(media, id) > 0 {
                        Text("↻ Watched \(rewatch.count(media, id) + 1)×")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0xA06BFF))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(hex: 0xA06BFF).opacity(0.18), in: Capsule())
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func metaLine(_ d: TitleDetail) -> String {
        var parts: [String] = []
        if let y = d.year { parts.append(y) }
        if media == .tv {
            if let s = d.numberOfSeasons { parts.append("\(s) Season\(s == 1 ? "" : "s")") }
            if let e = d.numberOfEpisodes { parts.append("\(e) Episodes") }
        } else if let r = d.runtime, r > 0 {
            parts.append("\(r / 60)h \(r % 60)m")
        }
        if let g = d.genres?.prefix(2).map(\.name), !g.isEmpty { parts.append(g.joined(separator: " · ")) }
        return parts.joined(separator: "  •  ")
    }

    private var heroSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            Shimmer().frame(maxWidth: .infinity).frame(height: 320)
            Shimmer().frame(width: 200, height: 22).clipShape(Capsule()).padding(.horizontal, 16)
        }
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5), in: Circle())
        }
        .padding(.leading, 14)
        .padding(.top, 8)
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { showStatusSheet = true } label: {
                HStack(spacing: 8) {
                    if let entry {
                        Circle().fill(entry.status.color).frame(width: 8, height: 8)
                        Text(entry.status.label)
                    } else {
                        Image(systemName: "plus")
                        Text("Add Status")
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(entry != nil ? entry!.status.color.opacity(0.18) : Theme.panelRaised,
                            in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(entry?.status.color.opacity(0.5) ?? Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.text)
            }
            Button { showRateSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.gold)
                    Text(ratings.rating(media, id).map { String(format: "%.1f", $0) } ?? "Rate")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.text)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func secondaryActions(_ d: TitleDetail) -> some View {
        HStack(spacing: 10) {
            Button { showReviewsSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text(reviews.count(media, id) > 0 ? "Reviews · \(reviews.count(media, id))" : "Reviews")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(reviews.count(media, id) > 0 ? Theme.green : Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.text)
            }
            if entry?.status == .completed || entry?.status == .caughtup || rewatch.count(media, id) > 0 {
                Button { startRewatch() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(rewatch.count(media, id) > 0 ? "Rewatch · \(rewatch.count(media, id))×" : "Rewatch")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(hex: 0xA06BFF).opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Color(hex: 0xA06BFF), lineWidth: 1))
                    .foregroundStyle(Color(hex: 0xA06BFF))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func startRewatch() {
        rewatch.increment(media, id)
        if media == .tv { ProgressStore.shared.clearShow(id) }
        library.setStatus(media, String(id), .watching)
    }

    // MARK: Live Activity (Dynamic Island + Lock Screen)

    private func liveActivityButton(_ d: TitleDetail) -> some View {
        let active = live.isActive(id)
        return Button {
            Task {
                if active {
                    await live.end(id: id)
                } else {
                    let info = watchProgress(d)
                    live.start(title: d.displayTitle, media: media, id: id,
                               posterPath: d.posterPath, progress: info.progress, subtitle: info.subtitle)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: active ? "stop.circle.fill" : "livephoto")
                Text(active ? "Stop Live Activity" : "Track on Lock Screen")
            }
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(active ? Theme.orange.opacity(0.18) : Theme.panelRaised,
                        in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(active ? Theme.orange : Theme.line, lineWidth: 1))
            .foregroundStyle(active ? Theme.orange : Theme.text)
        }
        .buttonStyle(.plain)
        .disabled(!live.isSupported)
        .padding(.horizontal, 16)
    }

    /// Current watch progress (0…1) + a caption for the Live Activity.
    private func watchProgress(_ d: TitleDetail) -> (progress: Double, subtitle: String) {
        if media == .tv, let total = d.numberOfEpisodes, total > 0 {
            let watched = progress.watchedCount(id)
            return (min(Double(watched) / Double(total), 1), "\(watched)/\(total) episodes")
        }
        return (0.05, "Just started")
    }

    private func ratingsRow(_ d: TitleDetail) -> some View {
        HStack(spacing: 18) {
            ratingChip(label: "TMDb", value: d.voteAverage.map { String(format: "%.1f", $0) }, color: Theme.blue)
            if let mine = ratings.rating(media, id) {
                ratingChip(label: "PlotLine", value: String(format: "%.1f", mine), color: Theme.green)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func ratingChip(label: String, value: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Theme.faint)
            Text(value ?? "—").font(.system(size: 17, weight: .bold)).foregroundStyle(color)
        }
    }

    // MARK: Rails

    private func seasonsRail(_ d: TitleDetail, _ seasons: [SeasonSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Seasons").padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(seasons) { s in
                        Button { seasonSheet = s } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RemoteImage(path: s.posterPath ?? d.posterPath, size: "w342")
                                    .frame(width: 120, height: 120 / Theme.posterAspect)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                                Text(s.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text("\(s.episodeCount ?? 0) episodes").font(.system(size: 11)).foregroundStyle(Theme.muted)
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func videosRail(_ videos: [Video]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Videos & Trailers").padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(videos.prefix(12)) { v in
                        Button { videoKey = VideoKey(key: v.key) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(v.key)/hqdefault.jpg")) { phase in
                                        if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                                        else { Theme.panelRaised }
                                    }
                                    .frame(width: 220, height: 124).clipped()
                                    Image(systemName: "play.circle.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.9))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                                Text(v.name).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1).frame(width: 220, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func castRail(_ cast: [CastMember]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cast").padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(cast.prefix(20)) { c in
                        VStack(spacing: 6) {
                            RemoteImage(path: c.profilePath, size: "w185")
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                            Text(c.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center).lineLimit(2).frame(width: 80)
                            if let ch = c.character {
                                Text(ch).font(.system(size: 10)).foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.center).lineLimit(1).frame(width: 80)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Sheets

    private var statusSheet: some View {
        NavigationStack {
            List {
                ForEach(LibStatus.order) { s in
                    Button {
                        library.setStatus(media, String(id), s)
                        showStatusSheet = false
                    } label: {
                        HStack {
                            Circle().fill(s.color).frame(width: 10, height: 10)
                            Text(s.label).foregroundStyle(Theme.text)
                            Spacer()
                            if entry?.status == s { Image(systemName: "checkmark").foregroundStyle(Theme.orange) }
                        }
                    }
                    .listRowBackground(Theme.panel)
                }
                if entry != nil {
                    Button(role: .destructive) {
                        library.clear(media, String(id))
                        showStatusSheet = false
                    } label: { Text("Remove from library") }
                        .listRowBackground(Theme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Set status")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var rateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Your rating").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                let current = ratings.rating(media, id) ?? 0
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(1...10, id: \.self) { n in
                        Button {
                            ratings.setQuick(media, id, Double(n))
                            showRateSheet = false
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Double(n) <= current ? Theme.green.opacity(0.25) : Theme.panelRaised,
                                            in: RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Double(n) <= current ? Theme.green : Theme.line, lineWidth: 1))
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
                if current > 0 {
                    Button(role: .destructive) {
                        ratings.clear(media, id); showRateSheet = false
                    } label: { Text("Clear rating") }
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
        .preferredColorScheme(.dark)
    }
}

/// Identifiable wrapper so a YouTube key can drive a `.sheet(item:)`.
struct VideoKey: Identifiable {
    let id = UUID()
    let key: String
}

@Observable
final class DetailModel {
    var detail: TitleDetail?

    @MainActor
    func load(media: MediaKind, id: Int) async {
        if detail != nil { return }
        let q = "append_to_response=credits,videos,recommendations,similar,external_ids,images&include_image_language=en,null"
        detail = await TMDBService.shared.get("/\(media.rawValue)/\(id)", q: q, as: TitleDetail.self)
    }
}

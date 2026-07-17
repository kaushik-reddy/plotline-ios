import SwiftUI

/// Episode Ratings heatmap (TV) — rows are seasons, columns are episodes, cells colored by
/// TMDB rating (red → amber → green). Ported from the web `EpisodeRatingMap.tsx`.
struct EpisodeRatingMap: View {
    let showId: Int
    let seasons: [SeasonSummary]

    @State private var grid: [Int: [Episode]] = [:]
    @State private var loading = true

    private var sortedSeasons: [SeasonSummary] { seasons.filter { $0.seasonNumber > 0 }.sorted { $0.seasonNumber < $1.seasonNumber } }
    private var allRated: [Episode] { grid.values.flatMap { $0 }.filter { ($0.voteAverage ?? 0) > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Episode Ratings", kicker: "Heatmap").padding(.horizontal, 16)

            if loading {
                HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }.padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedSeasons) { season in
                            HStack(spacing: 4) {
                                Text("S\(season.seasonNumber)")
                                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.muted)
                                    .frame(width: 26, alignment: .leading)
                                ForEach(grid[season.seasonNumber] ?? []) { ep in
                                    cell(ep)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                summary.padding(.horizontal, 16)
            }
        }
        .task { await load() }
    }

    private func cell(_ ep: Episode) -> some View {
        let r = ep.voteAverage ?? 0
        return Text(r > 0 ? String(format: "%.1f", r) : "–")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(r > 0 ? .white : Theme.faint)
            .frame(width: 28, height: 26)
            .background(color(for: r), in: RoundedRectangle(cornerRadius: 3))
    }

    private func color(for rating: Double) -> Color {
        guard rating > 0 else { return Theme.panelRaised }
        let t = max(0, min((rating - 5) / 4, 1)) // 5→red … 9→green
        return Color(hue: 0.33 * t, saturation: 0.62, brightness: 0.5)
    }

    private var summary: some View {
        HStack(spacing: 14) {
            if let best = allRated.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
                label("Best", best, Theme.green)
            }
            if let low = allRated.min(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
                label("Lowest", low, Theme.red)
            }
            Spacer()
        }
        .font(.system(size: 11))
    }

    private func label(_ title: String, _ ep: Episode, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(Theme.faint)
            Text("S\(ep.seasonNumber)E\(ep.episodeNumber)").foregroundStyle(color).bold()
            Text(String(format: "%.1f", ep.voteAverage ?? 0)).foregroundStyle(Theme.muted)
        }
    }

    private func load() async {
        guard grid.isEmpty else { return }
        for season in sortedSeasons {
            if let detail = await TMDBService.shared.get("/tv/\(showId)/season/\(season.seasonNumber)", as: SeasonDetail.self) {
                grid[season.seasonNumber] = detail.episodes
            }
        }
        loading = false
    }
}

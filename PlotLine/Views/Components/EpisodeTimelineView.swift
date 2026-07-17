import SwiftUI

/// Episode Timeline (TV) — last aired episode + next up with a live countdown, ported from the
/// web `EpisodeTimeline.tsx`. Reads `last_episode_to_air` / `next_episode_to_air` from details.
struct EpisodeTimelineView: View {
    let detail: TitleDetail

    var body: some View {
        if detail.lastEpisodeToAir != nil || detail.nextEpisodeToAir != nil {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Episodes", kicker: "Timeline")
                VStack(spacing: 0) {
                    if let last = detail.lastEpisodeToAir {
                        row(last, dotColor: Theme.green, label: "Last aired", showConnector: detail.nextEpisodeToAir != nil, countdown: nil)
                    }
                    if let next = detail.nextEpisodeToAir {
                        row(next, dotColor: Theme.orange, label: "Next episode", showConnector: false,
                            countdown: airDate(next.airDate))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func airDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        // Assume ~8pm local for the drop, matching the web's air-time heuristic.
        guard let day = f.date(from: s) else { return nil }
        return Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: day)
    }

    private func row(_ ep: EpisodeBrief, dotColor: Color, label: String, showConnector: Bool, countdown: Date?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Circle().fill(dotColor).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Theme.bg, lineWidth: 3).scaleEffect(1.6))
                if showConnector {
                    Rectangle().fill(Theme.line).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            HStack(spacing: 12) {
                RemoteImage(path: ep.stillPath ?? detail.backdropPath, size: "w300")
                    .frame(width: 108, height: 61)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text(label.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(dotColor)
                    Text(ep.name ?? "Episode").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("S\(ep.seasonNumber ?? 0) E\(ep.episodeNumber ?? 0)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        if let target = countdown, target > Date() {
                            CountdownText(target: target).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.green)
                        } else if let d = ep.airDate {
                            Text("· \(d)").font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, showConnector ? 14 : 0)
        }
    }
}

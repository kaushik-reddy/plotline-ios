import SwiftUI

/// Season playground — a per-episode workspace, ported from the web `SeasonModal.tsx`. For each
/// episode you can mark watched / skip, scrub runtime progress, mark "this & earlier", and read
/// or post comments. Progress syncs to the shared library (Continue Watching, status, calendar).
struct SeasonPlaygroundView: View {
    let showId: Int
    let showName: String
    let season: SeasonSummary
    let posterFallback: String?

    @Environment(\.dismiss) private var dismiss
    @State private var progress = ProgressStore.shared
    @State private var comments = CommentsStore.shared
    @State private var episodes: [Episode] = []
    @State private var loading = true
    @State private var expandedComments: Int? = nil
    @State private var commentDraft = ""

    private var watched: Int { episodes.filter { progress.state(showId, $0.seasonNumber, $0.episodeNumber).watched }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView().tint(Theme.orange).padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        ForEach(episodes) { ep in
                            episodeRow(ep)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Theme.bg)
            .navigationTitle(season.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 6).frame(width: 56, height: 56)
                Circle().trim(from: 0, to: episodes.isEmpty ? 0 : CGFloat(watched) / CGFloat(episodes.count))
                    .stroke(watched == episodes.count && !episodes.isEmpty ? Theme.green : Theme.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                Text("\(episodes.isEmpty ? 0 : Int(Double(watched) / Double(episodes.count) * 100))%")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(showName).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                Text("\(watched)/\(episodes.count) watched").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                for ep in episodes { progress.setWatched(showId, ep.seasonNumber, ep.episodeNumber, true) }
                syncLibrary()
            } label: {
                Text("Mark all").font(.system(size: 12, weight: .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func episodeRow(_ ep: Episode) -> some View {
        let st = progress.state(showId, ep.seasonNumber, ep.episodeNumber)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RemoteImage(path: ep.stillPath ?? posterFallback, size: "w300")
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if st.watched {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                                .padding(4)
                        } else if st.skipped {
                            Text("Skipped").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule()).padding(4)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("E\(ep.episodeNumber) · \(ep.name ?? "")").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    Text(metaLine(ep)).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            // Runtime scrubber.
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { progress.state(showId, ep.seasonNumber, ep.episodeNumber).frac },
                    set: { progress.setFrac(showId, ep.seasonNumber, ep.episodeNumber, $0); syncLibrary() }
                ), in: 0...1)
                .tint(st.watched ? Theme.green : Theme.orange)
                Text("\(Int(st.frac * 100))%").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 34)
            }

            // Actions.
            HStack(spacing: 10) {
                actionButton(st.watched ? "Watched" : "Mark watched", color: st.watched ? Theme.green : Theme.text, filled: st.watched) {
                    progress.setWatched(showId, ep.seasonNumber, ep.episodeNumber, !st.watched); syncLibrary()
                }
                actionButton("This & earlier", color: Theme.text, filled: false) {
                    for e in episodes where e.episodeNumber <= ep.episodeNumber {
                        progress.setWatched(showId, e.seasonNumber, e.episodeNumber, true)
                    }
                    syncLibrary()
                }
                actionButton(st.skipped ? "Skipped" : "Skip", color: Theme.amber, filled: st.skipped) {
                    progress.setSkipped(showId, ep.seasonNumber, ep.episodeNumber, !st.skipped); syncLibrary()
                }
                Spacer()
                Button {
                    expandedComments = expandedComments == ep.episodeNumber ? nil : ep.episodeNumber
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(comments.count(showId, ep.seasonNumber, ep.episodeNumber))")
                    }
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }

            if expandedComments == ep.episodeNumber {
                commentsPanel(ep)
            }
        }
        .padding(12)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private func commentsPanel(_ ep: Episode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(comments.comments(showId, ep.seasonNumber, ep.episodeNumber)) { c in
                VStack(alignment: .leading, spacing: 2) {
                    Text("You").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(c.text).font(.system(size: 12.5)).foregroundStyle(Theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $commentDraft)
                    .font(.system(size: 13)).foregroundStyle(Theme.text)
                    .padding(9)
                    .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                Button("Post") {
                    comments.add(showId, ep.seasonNumber, ep.episodeNumber, text: commentDraft)
                    commentDraft = ""
                }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                .disabled(commentDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.top, 4)
    }

    private func actionButton(_ title: String, color: Color, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .bold))
                .foregroundStyle(filled ? .black : color)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(filled ? color : Theme.panelRaised, in: Capsule())
                .overlay(Capsule().stroke(filled ? .clear : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func metaLine(_ ep: Episode) -> String {
        var parts: [String] = []
        if let d = ep.airDate { parts.append(d) }
        if let r = ep.runtime, r > 0 { parts.append("\(r)m") }
        if let v = ep.voteAverage, v > 0 { parts.append(String(format: "★ %.1f", v)) }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        if let detail = await TMDBService.shared.get("/tv/\(showId)/season/\(season.seasonNumber)", as: SeasonDetail.self) {
            episodes = detail.episodes
        }
        loading = false
    }

    /// Keep the library status roughly in sync (watching when partial, completed when all done).
    private func syncLibrary() {
        let lib = LibraryStore.shared
        guard !episodes.isEmpty else { return }
        let done = watched
        if done == 0 { return }
        let entry = lib.entry(.tv, showId)
        if done >= episodes.count, entry?.status != .caughtup {
            lib.setStatus(.tv, String(showId), .watching)
        } else if entry == nil || entry?.status == .watchlist {
            lib.setStatus(.tv, String(showId), .watching)
        }
    }
}

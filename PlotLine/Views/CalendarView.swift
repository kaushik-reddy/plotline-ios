import SwiftUI

/// A single dated calendar entry.
struct CalEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let subtitle: String
    let posterPath: String?
    let ref: TitleRef
    let accent: Color
}

/// Calendar — upcoming releases and episodes. Mirrors the web Calendar: a personal
/// "My Calendar" (your scheduled titles + tracked shows' next episodes) plus a global
/// "Coming Soon" list of upcoming movies, grouped by day.
struct CalendarView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model = CalendarModel()
    @State private var tab: Tab = .mine

    enum Tab: String, CaseIterable { case mine = "My Calendar", global = "Coming Soon" }

    private var events: [CalEvent] { tab == .mine ? model.mine : model.global }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if events.isEmpty {
                    emptyOrLoading
                } else {
                    ForEach(groupedKeys, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle().fill(Theme.orange).frame(width: 7, height: 7)
                                Text(dayLabel(day))
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Theme.text)
                                Text("· \(grouped[day]?.count ?? 0)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            }
                            ForEach(grouped[day] ?? []) { ev in
                                CalRow(event: ev)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(PageBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(library: library) }
    }

    private var grouped: [Date: [CalEvent]] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
    }
    private var groupedKeys: [Date] { grouped.keys.sorted() }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInTomorrow(d) { return "Tomorrow" }
        f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }

    private var emptyOrLoading: some View {
        Group {
            if model.loading {
                HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }.padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 30)).foregroundStyle(Theme.faint)
                    Text(tab == .mine ? "Nothing scheduled yet" : "No upcoming releases")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity).padding(.top, 50)
            }
        }
    }
}

private struct CalRow: View {
    let event: CalEvent
    var body: some View {
        NavigationLink(value: event.ref) {
            HStack(spacing: 12) {
                RemoteImage(path: event.posterPath, size: "w300")
                    .frame(width: 108, height: 61)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(event.accent)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

@Observable
final class CalendarModel {
    var mine: [CalEvent] = []
    var global: [CalEvent] = []
    var loading = false
    private var loaded = false

    @MainActor
    func load(library: LibraryStore) async {
        if loaded { return }
        loaded = true
        loading = true
        let svc = TMDBService.shared
        let now = Date()
        let isoDay = DateFormatter()
        isoDay.dateFormat = "yyyy-MM-dd"

        // Global: upcoming movies.
        if let up = await svc.get("/movie/upcoming", as: PagedResults.self) {
            var out: [CalEvent] = []
            for m in up.results {
                guard let ds = m.releaseDate, let d = isoDay.date(from: ds), d >= Calendar.current.startOfDay(for: now) else { continue }
                out.append(CalEvent(date: d, title: m.displayTitle, subtitle: "Movie release",
                                    posterPath: m.backdropPath ?? m.posterPath,
                                    ref: TitleRef(media: .movie, id: m.id), accent: Theme.orange))
            }
            global = out.sorted { $0.date < $1.date }
        }

        // Personal: scheduled entries + tracked TV next episodes.
        var mineOut: [CalEvent] = []
        for entry in library.entries {
            guard let idInt = Int(entry.id) else { continue }
            if entry.status == .scheduled, let at = entry.scheduledAt {
                let d = Date(timeIntervalSince1970: at / 1000)
                if let det = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) {
                    mineOut.append(CalEvent(date: d, title: det.displayTitle,
                                            subtitle: entry.scheduledSub ?? "Scheduled",
                                            posterPath: det.backdropPath ?? det.posterPath,
                                            ref: TitleRef(media: entry.media, id: idInt), accent: Theme.orange))
                }
            } else if entry.media == .tv, entry.status == .watching || entry.status == .caughtup {
                if let det = await svc.get("/tv/\(entry.id)", as: TitleDetail.self),
                   let next = det.nextEpisodeToAir, let ds = next.airDate, let d = isoDay.date(from: ds), d >= Calendar.current.startOfDay(for: now) {
                    let se = "S\(next.seasonNumber ?? 0) E\(next.episodeNumber ?? 0)"
                    mineOut.append(CalEvent(date: d, title: det.displayTitle,
                                            subtitle: "New episode · \(se)",
                                            posterPath: next.stillPath ?? det.backdropPath,
                                            ref: TitleRef(media: .tv, id: idInt), accent: Theme.blue))
                }
            }
        }
        mine = mineOut.sorted { $0.date < $1.date }
        loading = false
    }
}

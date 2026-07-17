import SwiftUI

/// A dated calendar entry.
struct CalEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let posterPath: String?
    let ref: TitleRef
    let accent: Color
    let personal: Bool
}

/// Calendar — a native port of the web Calendar: five tabs (Digital, In Theaters, TV Premieres,
/// My Calendar, TV Schedule), a scrollable day strip, live countdowns, and mark-watched.
struct CalendarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ProgressStore.self) private var progress
    @State private var model = CalendarModel()
    @State private var tab: CalendarModel.Tab = .mine

    private var events: [CalEvent] { model.events[tab] ?? [] }
    private var grouped: [(day: Date, items: [CalEvent])] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tabStrip
                dayStrip

                if model.loading[tab] == true && events.isEmpty {
                    HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }.padding(.top, 50)
                } else if events.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(grouped, id: \.day) { group in
                                dayGroup(group.day, group.items).id(group.day)
                            }
                        }
                        .onChange(of: model.jumpDay) { _, day in
                            if let day { withAnimation { proxy.scrollTo(day, anchor: .top) } }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(PageBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: tab) { await model.load(tab: tab, library: library) }
    }

    // MARK: Tabs

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CalendarModel.Tab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(t.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tab == t ? .black : Theme.text)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(tab == t ? Theme.orange : Theme.panel, in: Capsule())
                            .overlay(Capsule().stroke(tab == t ? .clear : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Day strip

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(grouped, id: \.day) { group in
                    let isToday = Calendar.current.isDateInToday(group.day)
                    Button { model.jumpDay = group.day } label: {
                        VStack(spacing: 2) {
                            Text(weekday(group.day)).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.faint)
                            Text(dayNum(group.day)).font(.system(size: 16, weight: .heavy)).foregroundStyle(isToday ? Theme.orange : Theme.text)
                        }
                        .frame(width: 44, height: 48)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(isToday ? Theme.orange : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Day group

    private func dayGroup(_ day: Date, _ items: [CalEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Theme.orange).frame(width: 7, height: 7)
                Text(dayLabel(day)).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.text)
                Text("· \(items.count)").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            ForEach(items) { ev in
                CalRow(event: ev, watched: model.isWatched(ev.id)) { model.toggleWatched(ev.id) }
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar").font(.system(size: 30)).foregroundStyle(Theme.faint)
            Text("Nothing here yet").font(.system(size: 14)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.top, 50)
    }

    private func weekday(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d).uppercased() }
    private func dayNum(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d) }
    private func dayLabel(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInTomorrow(d) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: d)
    }
}

private struct CalRow: View {
    let event: CalEvent
    let watched: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: event.ref) {
                HStack(spacing: 12) {
                    RemoteImage(path: event.posterPath, size: "w300")
                        .frame(width: 108, height: 61)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
                        .opacity(watched ? 0.5 : 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text(event.subtitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(event.accent).lineLimit(1)
                        if event.date > Date() {
                            CountdownText(target: event.date).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.green)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button(action: onToggle) {
                Image(systemName: watched ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(watched ? Theme.green : Theme.faint)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }
}

@Observable
final class CalendarModel {
    enum Tab: String, CaseIterable {
        case digital, theaters, premieres, mine, schedule
        var label: String {
            switch self {
            case .digital: return "Digital"
            case .theaters: return "In Theaters"
            case .premieres: return "TV Premieres"
            case .mine: return "My Calendar"
            case .schedule: return "TV Schedule"
            }
        }
    }

    var events: [Tab: [CalEvent]] = [:]
    var loading: [Tab: Bool] = [:]
    var jumpDay: Date?

    private let watchedKey = "pl_cal_watched"
    private var watched: Set<String> = []

    init() {
        if let arr = UserDefaults.standard.array(forKey: watchedKey) as? [String] { watched = Set(arr) }
    }

    func isWatched(_ id: String) -> Bool { watched.contains(id) }
    func toggleWatched(_ id: String) {
        if watched.contains(id) { watched.remove(id) } else { watched.insert(id) }
        UserDefaults.standard.set(Array(watched), forKey: watchedKey)
    }

    @MainActor
    func load(tab: Tab, library: LibraryStore) async {
        if events[tab] != nil { return }
        loading[tab] = true
        let svc = TMDBService.shared
        let iso = DateFormatter(); iso.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let start = iso.string(from: now)
        let end = iso.string(from: Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now)
        let today = Calendar.current.startOfDay(for: now)
        var out: [CalEvent] = []

        switch tab {
        case .digital:
            if let p = await svc.get("/discover/movie", q: "with_release_type=4|6&sort_by=popularity.desc&primary_release_date.gte=\(start)&primary_release_date.lte=\(end)&vote_count.gte=5", as: PagedResults.self) {
                for m in p.results {
                    guard let ds = m.releaseDate, let d = iso.date(from: ds), d >= today else { continue }
                    out.append(CalEvent(id: "d\(m.id)", date: d, title: m.displayTitle, subtitle: "Digital release",
                                        posterPath: m.backdropPath ?? m.posterPath, ref: TitleRef(media: .movie, id: m.id), accent: Theme.orange, personal: false))
                }
            }
        case .theaters:
            if let p = await svc.get("/movie/now_playing", as: PagedResults.self) {
                for m in p.results {
                    guard let ds = m.releaseDate, let d = iso.date(from: ds) else { continue }
                    out.append(CalEvent(id: "t\(m.id)", date: d, title: m.displayTitle, subtitle: "In theaters",
                                        posterPath: m.backdropPath ?? m.posterPath, ref: TitleRef(media: .movie, id: m.id), accent: Theme.amber, personal: false))
                }
            }
        case .premieres:
            if let p = await svc.get("/discover/tv", q: "sort_by=popularity.desc&first_air_date.gte=\(start)&first_air_date.lte=\(end)", as: PagedResults.self) {
                for t in p.results {
                    guard let ds = t.firstAirDate, let d = iso.date(from: ds), d >= today else { continue }
                    out.append(CalEvent(id: "pr\(t.id)", date: d, title: t.displayTitle, subtitle: "Series premiere",
                                        posterPath: t.backdropPath ?? t.posterPath, ref: TitleRef(media: .tv, id: t.id), accent: Theme.blue, personal: false))
                }
            }
        case .mine:
            out = await personalEvents(library: library, iso: iso, today: today, includeScheduled: true)
        case .schedule:
            out = await personalEvents(library: library, iso: iso, today: today, includeScheduled: false)
        }

        events[tab] = out.sorted { $0.date < $1.date }
        loading[tab] = false
    }

    @MainActor
    private func personalEvents(library: LibraryStore, iso: DateFormatter, today: Date, includeScheduled: Bool) async -> [CalEvent] {
        let svc = TMDBService.shared
        var out: [CalEvent] = []
        for entry in library.entries {
            guard let idInt = Int(entry.id) else { continue }
            if includeScheduled, entry.status == .scheduled, let at = entry.scheduledAt {
                if let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) {
                    out.append(CalEvent(id: "s\(entry.key)", date: Date(timeIntervalSince1970: at / 1000), title: d.displayTitle,
                                        subtitle: entry.scheduledSub ?? "Scheduled", posterPath: d.backdropPath ?? d.posterPath,
                                        ref: TitleRef(media: entry.media, id: idInt), accent: Theme.orange, personal: true))
                }
            }
            if entry.media == .tv, entry.status == .watching || entry.status == .caughtup {
                if let d = await svc.get("/tv/\(entry.id)", as: TitleDetail.self),
                   let next = d.nextEpisodeToAir, let ds = next.airDate, let date = iso.date(from: ds), date >= today {
                    out.append(CalEvent(id: "e\(entry.id)-\(next.seasonNumber ?? 0)-\(next.episodeNumber ?? 0)", date: date, title: d.displayTitle,
                                        subtitle: "New episode · S\(next.seasonNumber ?? 0) E\(next.episodeNumber ?? 0)",
                                        posterPath: next.stillPath ?? d.backdropPath, ref: TitleRef(media: .tv, id: idInt), accent: Theme.blue, personal: true))
                }
            }
        }
        return out
    }
}

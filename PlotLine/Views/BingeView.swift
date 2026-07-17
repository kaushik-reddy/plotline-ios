import SwiftUI

/// Binge — your personal library. Mirrors the web Binge page: media filter (All / Movies
/// / Shows), status filter chips with counts, and a poster grid of everything you track.
struct BingeView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model = BingeModel()
    @State private var media: MediaFilter = .all
    @State private var status: LibStatus? = nil

    enum MediaFilter: String, CaseIterable { case all = "All", movie = "Movies", tv = "Shows" }

    private var filtered: [BingeEntry] {
        model.entries.filter { e in
            (media == .all || (media == .movie && e.media == .movie) || (media == .tv && e.media == .tv)) &&
            (status == nil || e.status == status)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $media) {
                    ForEach(MediaFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                statusChips

                if model.loading && model.entries.isEmpty {
                    HStack { Spacer(); ProgressView().tint(Theme.orange); Spacer() }.padding(.top, 40)
                } else if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack").font(.system(size: 30)).foregroundStyle(Theme.faint)
                        Text("Nothing here yet").font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 50)
                } else {
                    let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(filtered) { e in
                            PosterCard(item: e.item, media: e.media, width: 108)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(PageBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(library: library) }
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "All", count: model.entries.count)
                ForEach(LibStatus.order) { s in
                    let c = model.entries.filter { $0.status == s }.count
                    if c > 0 { chip(s, label: s.label, count: c) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ s: LibStatus?, label: String, count: Int) -> some View {
        let active = status == s
        return Button { status = s } label: {
            HStack(spacing: 6) {
                if let s { Circle().fill(s.color).frame(width: 7, height: 7) }
                Text(label).font(.system(size: 12, weight: .semibold))
                Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(active ? Theme.panelRaised : Theme.panel, in: Capsule())
            .overlay(Capsule().stroke(active ? (s?.color ?? Theme.orange) : Theme.line, lineWidth: 1))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
    }
}

struct BingeEntry: Identifiable {
    let item: TitleItem
    let media: MediaKind
    let status: LibStatus
    var id: String { "\(media.rawValue):\(item.id)" }
}

@Observable
final class BingeModel {
    var entries: [BingeEntry] = []
    var loading = false
    private var loadedKeys: Set<String> = []

    @MainActor
    func load(library: LibraryStore) async {
        loading = true
        let svc = TMDBService.shared
        var out = entries
        for entry in library.entries {
            let key = entry.key
            if loadedKeys.contains(key) { continue }
            guard let idInt = Int(entry.id),
                  let d = await svc.get("/\(entry.media.rawValue)/\(entry.id)", as: TitleDetail.self) else { continue }
            loadedKeys.insert(key)
            let item = TitleItem(id: idInt, title: d.title, name: d.name, posterPath: d.posterPath,
                                 backdropPath: d.backdropPath, overview: d.overview, voteAverage: d.voteAverage,
                                 releaseDate: d.releaseDate, firstAirDate: d.firstAirDate,
                                 originalLanguage: d.originalLanguage, mediaTypeRaw: entry.media.rawValue)
            out.append(BingeEntry(item: item, media: entry.media, status: entry.status))
        }
        // Keep only entries still in the library, and refresh their status.
        let byKey = Dictionary(uniqueKeysWithValues: library.entries.map { ($0.key, $0.status) })
        entries = out.compactMap { e in
            guard let st = byKey["\(e.media.rawValue):\(e.item.id)"] else { return nil }
            return BingeEntry(item: e.item, media: e.media, status: st)
        }
        loading = false
    }
}

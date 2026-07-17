import SwiftUI
import UniformTypeIdentifiers

/// One parsed import row, resolved against TMDB.
struct ImportRow: Identifiable {
    let id = UUID()
    let sourceTitle: String
    let year: String?
    let sourceRating: Double?
    var match: TitleItem? = nil
    var media: MediaKind = .movie
    var status: LibStatus = .completed
    var resolved = false
}

/// Import wizard — bring in your watch history from an IMDb or Letterboxd CSV export. Parses the
/// file, resolves each title against TMDB, lets you review, then adds everything to your library.
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ImportRow] = []
    @State private var showPicker = false
    @State private var busy = false
    @State private var progressText = ""
    @State private var committed = false

    private var matched: [ImportRow] { rows.filter { $0.resolved && $0.match != nil } }

    var body: some View {
        NavigationStack {
            Group {
                if committed {
                    receipt
                } else if rows.isEmpty {
                    intro
                } else {
                    reviewList
                }
            }
            .background(Theme.bg)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.tint(Theme.orange) } }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await handleFile(url) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 44)).foregroundStyle(Theme.orange)
            Text("Import your history").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
            Text("Pick an IMDb ratings export or a Letterboxd CSV. We'll match each title against TMDB and add it to your library.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 24)
            if busy {
                ProgressView(progressText).tint(Theme.orange).foregroundStyle(Theme.muted)
            } else {
                Button { showPicker = true } label: {
                    Text("Choose CSV file").font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 28).padding(.vertical, 12).background(Theme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Review

    private var reviewList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(matched.count) of \(rows.count) matched").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(16)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($rows) { $row in
                        importRow($row)
                    }
                }
                .padding(.horizontal, 16)
            }
            Button {
                commit()
            } label: {
                Text("Add \(matched.count) titles to library").font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.orange, in: RoundedRectangle(cornerRadius: Theme.radius))
            }
            .buttonStyle(.plain).disabled(matched.isEmpty).padding(16)
        }
    }

    private func importRow(_ row: Binding<ImportRow>) -> some View {
        HStack(spacing: 12) {
            RemoteImage(path: row.wrappedValue.match?.posterPath, size: "w185")
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(row.wrappedValue.match == nil ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.wrappedValue.match?.displayTitle ?? row.wrappedValue.sourceTitle)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                if row.wrappedValue.match == nil {
                    Text("No TMDB match").font(.system(size: 11)).foregroundStyle(Theme.red)
                } else {
                    Text("\(row.wrappedValue.media.label)\(row.wrappedValue.year.map { " · " + $0 } ?? "")")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if row.wrappedValue.match != nil {
                Menu {
                    ForEach(LibStatus.order) { s in
                        Button(s.label) { row.wrappedValue.status = s }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(row.wrappedValue.status.color).frame(width: 7, height: 7)
                        Text(row.wrappedValue.status.label).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.text).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.panelRaised, in: Capsule())
                }
            }
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Receipt

    private var receipt: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(Theme.green)
            Text("Imported \(matched.count) titles").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
            Text("They're now in your library, Binge and Profile.").font(.system(size: 14)).foregroundStyle(Theme.muted)
            Button { dismiss() } label: {
                Text("Done").font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 28).padding(.vertical, 12).background(Theme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: File handling

    private func handleFile(_ url: URL) async {
        busy = true
        progressText = "Reading file…"
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            busy = false; progressText = "Couldn't read file"; return
        }
        var parsed = parseImport(text)
        // Resolve against TMDB.
        for i in parsed.indices {
            progressText = "Matching \(i + 1)/\(parsed.count)…"
            if let (item, media) = await resolve(parsed[i]) {
                parsed[i].match = item
                parsed[i].media = media
            }
            parsed[i].resolved = true
        }
        rows = parsed
        busy = false
    }

    private func resolve(_ row: ImportRow) async -> (TitleItem, MediaKind)? {
        let page = await TMDBService.shared.get("/search/multi", q: "query=\(row.sourceTitle)", as: PagedResults.self)
        let candidates = (page?.results ?? []).filter { ($0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv") && $0.posterPath != nil }
        // Prefer a year match if we have one.
        if let y = row.year, let hit = candidates.first(where: { $0.year == y }) {
            return (hit, hit.kind())
        }
        if let hit = candidates.first { return (hit, hit.kind()) }
        return nil
    }

    private func commit() {
        for row in matched {
            guard let item = row.match else { continue }
            LibraryStore.shared.setStatus(row.media, String(item.id), row.status)
            if let r = row.sourceRating { RatingStore.shared.setQuick(row.media, item.id, r) }
        }
        committed = true
    }
}

// MARK: - CSV parsing

/// Parse an IMDb ratings export or Letterboxd CSV into import rows.
func parseImport(_ raw: String) -> [ImportRow] {
    let text = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let records = parseCSV(text)
    guard records.count > 1 else { return [] }
    let header = records[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

    func col(_ names: [String]) -> Int? { names.compactMap { header.firstIndex(of: $0) }.first }
    let titleCol = col(["title", "name"])
    let typeCol = col(["title type", "type"])
    let ratingCol = col(["your rating", "rating"])
    let yearCol = col(["year"])
    let isLetterboxd = header.contains("letterboxd uri") || (header.contains("name") && !header.contains("title"))
    guard let tc = titleCol else { return [] }

    var out: [ImportRow] = []
    for r in records.dropFirst() {
        guard r.count > tc else { continue }
        let title = r[tc].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { continue }
        let year = yearCol.flatMap { $0 < r.count ? r[$0].prefix(4).description : nil }?.trimmingCharacters(in: .whitespaces)
        var rating: Double? = ratingCol.flatMap { $0 < r.count ? Double(r[$0].trimmingCharacters(in: .whitespaces)) : nil }
        if isLetterboxd, let rv = rating { rating = rv * 2 } // Letterboxd 0.5–5 → 1–10
        out.append(ImportRow(sourceTitle: title, year: year, sourceRating: rating,
                             media: (typeCol.flatMap { $0 < r.count ? r[$0] : nil }?.lowercased().contains("tv") ?? false) ? .tv : .movie))
    }
    return out
}

/// Minimal RFC-4180-ish CSV parser (handles quoted fields, escaped quotes, newline records).
func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var record: [String] = []
    var field = ""
    var inQuotes = false
    let chars = Array(text)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if inQuotes {
            if c == "\"" {
                if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else { inQuotes = false }
            } else { field.append(c) }
        } else {
            switch c {
            case "\"": inQuotes = true
            case ",": record.append(field); field = ""
            case "\n": record.append(field); field = ""; rows.append(record); record = []
            default: field.append(c)
            }
        }
        i += 1
    }
    if !field.isEmpty || !record.isEmpty { record.append(field); rows.append(record) }
    return rows
}

import SwiftUI

/// Poster / backdrop picker — pick a different image for a title (stored as an override).
struct PosterPickerSheet: View {
    let media: MediaKind
    let id: Int
    let posters: [String]
    let backdrops: [String]

    @State private var store = PostersStore.shared
    @State private var tab = 0
    @Environment(\.dismiss) private var dismiss

    private var slot: String { tab == 0 ? "poster" : "backdrop" }
    private var options: [String] { tab == 0 ? posters : backdrops }
    private var columns: [GridItem] {
        tab == 0 ? [GridItem(.adaptive(minimum: 90), spacing: 10)] : [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $tab) {
                    Text("Posters").tag(0); Text("Backdrops").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(options, id: \.self) { path in
                            let selected = store.override(media, id, slot) == path
                            Button { store.set(media, id, slot, path) } label: {
                                RemoteImage(path: path, size: tab == 0 ? "w342" : "w780")
                                    .aspectRatio(tab == 0 ? Theme.posterAspect : 16.0 / 9.0, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(selected ? Theme.orange : Theme.line, lineWidth: selected ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }

                Button("Reset to default") { store.reset(media, id, slot) }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted).padding(.bottom, 12)
            }
            .background(Theme.bg)
            .navigationTitle("Choose image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(Theme.orange) } }
        }
        .preferredColorScheme(.dark)
    }
}

/// Reviews sheet — write a rating + review (with **markdown** and an optional spoiler flag),
/// and read your existing reviews.
struct ReviewSheet: View {
    let media: MediaKind
    let id: Int
    let isTv: Bool

    @State private var store = ReviewsStore.shared
    @State private var rating: Double = 8
    @State private var text = ""
    @State private var spoiler = false
    @State private var scope: String
    @Environment(\.dismiss) private var dismiss

    init(media: MediaKind, id: Int, isTv: Bool) {
        self.media = media; self.id = id; self.isTv = isTv
        _scope = State(initialValue: isTv ? "Full show" : "Movie")
    }

    private let scopes = ["Full show", "This season", "This episode"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your rating").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(1...10, id: \.self) { n in
                            Button { rating = Double(n) } label: {
                                Text("\(n)").font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(Double(n) <= rating ? Theme.green.opacity(0.25) : Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Double(n) <= rating ? Theme.green : Theme.line, lineWidth: 1))
                                    .foregroundStyle(Theme.text)
                            }
                        }
                    }

                    if isTv {
                        Picker("Scope", selection: $scope) {
                            ForEach(scopes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text("Review").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                        .foregroundStyle(Theme.text)
                    Text("Supports **bold**, *italic*. Toggle spoiler to hide it until tapped.")
                        .font(.system(size: 11)).foregroundStyle(Theme.faint)

                    Toggle("Contains spoilers", isOn: $spoiler)
                        .font(.system(size: 13)).tint(Theme.orange)

                    Button {
                        store.add(media, id, rating: rating, text: text, scope: scope, spoiler: spoiler)
                        text = ""; spoiler = false
                    } label: {
                        Text("Post review").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.orange, in: RoundedRectangle(cornerRadius: Theme.radius))
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                    let existing = store.reviews(media, id)
                    if !existing.isEmpty {
                        Text("Reviews · \(existing.count)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text).padding(.top, 6)
                        ForEach(existing) { ReviewRow(review: $0) }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(Theme.orange) } }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ReviewRow: View {
    let review: Review
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("You").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Theme.green)
                    Text(String(format: "%.0f/10", review.rating)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.green)
                }
                Text("· \(review.scope)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Spacer()
            }
            Text(LocalizedStringKey(review.text))
                .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: review.spoiler && !revealed ? 6 : 0)
                .overlay {
                    if review.spoiler && !revealed {
                        Button { revealed = true } label: {
                            Text("Tap to reveal spoiler").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.orange)
                        }
                    }
                }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }
}

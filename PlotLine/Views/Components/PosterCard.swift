import SwiftUI

/// A navigable reference to a title, used with `navigationDestination`. Corresponds to
/// the web route `/title/:media/:id`.
struct TitleRef: Hashable {
    let media: MediaKind
    let id: Int
}

/// Portrait poster card (2:3) with status pill, rating badge and caption — the core
/// building block of every rail/grid, mirroring the web Explore/Binge cards.
struct PosterCard: View {
    let item: TitleItem
    var media: MediaKind? = nil
    var width: CGFloat = 128

    @Environment(LibraryStore.self) private var library

    private var kind: MediaKind { media ?? item.kind() }

    var body: some View {
        NavigationLink(value: TitleRef(media: kind, id: item.id)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(path: item.posterPath, size: "w342")
                        .frame(width: width, height: width / Theme.posterAspect)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))

                    if let entry = library.entry(kind, item.id) {
                        StatusPill(status: entry.status, compact: true)
                            .padding(6)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            RatingBadge(value: item.voteAverage)
                            Spacer()
                        }
                        .padding(6)
                    }
                    .frame(width: width, height: width / Theme.posterAspect)
                }

                Text(item.displayTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if let year = item.year {
                    Text(year)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

/// A horizontally scrolling rail of poster cards with a section header.
struct PosterRail: View {
    let title: String
    var kicker: String? = nil
    let items: [TitleItem]
    var media: MediaKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, kicker: kicker)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        PosterCard(item: item, media: media)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Full-bleed page background used by every screen.
struct PageBackground: View {
    var body: some View {
        Theme.bg.ignoresSafeArea()
    }
}

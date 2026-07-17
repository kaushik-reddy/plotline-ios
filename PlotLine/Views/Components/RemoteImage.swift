import SwiftUI

/// A poster/still image loaded through the TMDB proxy mirror, with a shimmering
/// placeholder while loading and a graceful fallback (matches the web `Img` component).
struct RemoteImage: View {
    let path: String?
    var size: String = "w342"
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let url = TMDBService.img(size, path) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        Shimmer()
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.panelRaised
            Image(systemName: "film")
                .font(.system(size: 22))
                .foregroundStyle(Theme.faint)
        }
    }
}

/// A subtle animated shimmer used as an image/skeleton placeholder.
struct Shimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [Theme.panel, Theme.panelRaised, Theme.panel],
                startPoint: .leading, endPoint: .trailing
            )
            .offset(x: phase * geo.size.width)
            .background(Theme.panel)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .background(Theme.panel)
    }
}

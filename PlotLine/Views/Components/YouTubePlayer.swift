import SwiftUI
import WebKit

/// Inline YouTube player used for trailers/videos (matches the web app's inline video modal).
struct YouTubePlayer: UIViewRepresentable {
    let key: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let src = "https://www.youtube-nocookie.com/embed/\(key)?autoplay=1&playsinline=1&rel=0"
        if web.url?.absoluteString != src, let url = URL(string: src) {
            web.load(URLRequest(url: url))
        }
    }
}

/// A sheet that plays a YouTube video by key.
struct VideoSheet: View {
    let key: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            YouTubePlayer(key: key)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

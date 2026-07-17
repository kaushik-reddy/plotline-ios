import SwiftUI

/// The app's root: the real PlotLine web app rendered full-screen in a `WKWebView`, so the
/// iOS app is a true pixel-for-pixel replica of the website. A branded splash covers the
/// first paint, and a friendly retry screen handles offline/load failures.
struct RootWebView: View {
    /// The live production site (same one the website serves).
    static let siteURL = URL(string: "https://gentle-desert-01c503400.7.azurestaticapps.net")!

    @State private var controller = WebController()
    @State private var isLoading = true
    @State private var loadError = false
    @State private var didFirstLoad = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            WebView(url: Self.siteURL, controller: controller, isLoading: $isLoading, loadError: $loadError)
                .ignoresSafeArea(edges: .bottom)

            if loadError {
                errorOverlay
            } else if isLoading && !didFirstLoad {
                splash
            }
        }
        .onChange(of: isLoading) { _, loading in
            if !loading { didFirstLoad = true }
        }
        .onOpenURL { url in
            // Deep link from the Live Activity / Dynamic Island: plotline://title/tv/123
            guard url.scheme == "plotline" else { return }
            var parts: [String] = []
            if let host = url.host { parts.append(host) }
            parts.append(contentsOf: url.pathComponents.filter { $0 != "/" })
            let path = "/" + parts.joined(separator: "/")
            if let target = URL(string: Self.siteURL.absoluteString + path) {
                controller.load(target)
            }
        }
    }

    // MARK: Splash

    private var splash: some View {
        VStack(spacing: 16) {
            Text("PLOTLINE")
                .font(.system(size: 24, weight: .heavy))
                .tracking(4)
                .foregroundStyle(Theme.text)
            ProgressView()
                .tint(Theme.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    // MARK: Error

    private var errorOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.orange)
            Text("Couldn't reach PlotLine")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Check your connection and try again.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
            Button {
                loadError = false
                isLoading = true
                controller.reload()
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.orange, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

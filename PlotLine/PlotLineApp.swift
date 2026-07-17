import SwiftUI

/// App entry point.
///
/// The UI is the **real PlotLine web app** rendered full-screen in a `WKWebView`
/// (`RootWebView`) — a true pixel-for-pixel replica of the website, with nothing missing,
/// because it *is* the same web app. Native iOS 26 features (Live Activities, Dynamic Island,
/// local notifications) are layered on via a JavaScript bridge (`window.PlotLineNative`).
///
/// The hand-written native SwiftUI screens (`RootTabView`, `HomeView`, …) remain in the repo
/// but are no longer the shell; the WebView supersedes them for exact web parity.
@main
struct PlotLineApp: App {
    @State private var live = LiveActivityManager.shared

    var body: some Scene {
        WindowGroup {
            RootWebView()
                .preferredColorScheme(.dark)
                .tint(Theme.orange)
                .task {
                    live.syncRunning()
                    await NotificationManager.shared.requestAuthorization()
                }
        }
    }
}


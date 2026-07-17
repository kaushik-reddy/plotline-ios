import SwiftUI

/// App entry point — a fully **native** SwiftUI rebuild of the PlotLine web app (no WebView).
/// A dark themed shell with a bottom tab bar (Home, Explore, Calendar, Binge) plus a Profile
/// destination reached via the header avatar. Native iOS 26 extras (Live Activities, Dynamic
/// Island, local notifications) are wired directly into the native screens.
@main
struct PlotLineApp: App {
    @State private var library = LibraryStore.shared
    @State private var progress = ProgressStore.shared
    @State private var ratings = RatingStore.shared
    @State private var region = RegionStore.shared
    @State private var sync = SyncService.shared
    @State private var avatar = ProfileStore_Avatar.shared
    @State private var live = LiveActivityManager.shared
    @State private var feed = FeedStore.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(library)
                .environment(progress)
                .environment(ratings)
                .environment(region)
                .environment(sync)
                .environment(avatar)
                .environment(live)
                .environment(feed)
                .preferredColorScheme(.dark)
                .tint(Theme.orange)
                .task {
                    await sync.pullIfLinked()
                    live.syncRunning()
                    await NotificationManager.shared.requestAuthorization()
                }
        }
    }
}


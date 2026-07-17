import SwiftUI

/// App entry point. Mirrors the web app's shell: a dark themed root with a bottom
/// tab bar (Home, Explore, Calendar, Binge) plus a Profile destination.
@main
struct PlotLineApp: App {
    // Global stores shared across every screen (same role as the web app's reactive
    // localStorage-backed stores: library, progress, ratings, region, sync).
    @State private var library = LibraryStore.shared
    @State private var progress = ProgressStore.shared
    @State private var ratings = RatingStore.shared
    @State private var region = RegionStore.shared
    @State private var sync = SyncService.shared
    @State private var avatar = ProfileStore_Avatar.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(library)
                .environment(progress)
                .environment(ratings)
                .environment(region)
                .environment(sync)
                .environment(avatar)
                .preferredColorScheme(.dark)
                .tint(Theme.orange)
                .task { await sync.pullIfLinked() }
        }
    }
}

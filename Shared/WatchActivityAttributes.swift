import ActivityKit
import Foundation

/// Shared Live Activity definition used by BOTH the app (to start/update/end activities)
/// and the widget extension (to render them in the Dynamic Island and on the Lock Screen).
///
/// This file is a member of the `PlotLine` app target AND the `PlotLineWidgets` extension
/// target — that's the standard ActivityKit sharing pattern.
struct WatchActivityAttributes: ActivityAttributes {
    /// The parts of the activity that change over time (progress, labels).
    public struct ContentState: Codable, Hashable {
        /// 0…1 watch progress for the ring / bar.
        var progress: Double
        /// e.g. "S2 E3 · 24 min left" or "Watching".
        var subtitle: String
        /// Short status verb shown in the Dynamic Island, e.g. "Watching" / "Paused".
        var statusText: String
    }

    /// Static metadata for the whole activity (doesn't change).
    var title: String
    var mediaKind: String   // "movie" | "tv"
    var posterPath: String?
    var tmdbId: Int
}

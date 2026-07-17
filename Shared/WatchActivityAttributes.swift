import ActivityKit
import Foundation

/// Shared Live Activity definition used by BOTH the app (to start/update/end activities)
/// and the widget extension (to render them in the Dynamic Island and on the Lock Screen).
///
/// This file is a member of the `PlotLine` app target AND the `PlotLineWidgets` extension
/// target — that's the standard ActivityKit sharing pattern.
struct WatchActivityAttributes: ActivityAttributes {
    /// The parts of the activity that change over time. `mode` lets a single activity switch
    /// between a "watching" progress view and a "countdown" timer (e.g. a scheduled watch
    /// that starts in 30 minutes) without recreating it.
    public struct ContentState: Codable, Hashable {
        /// "watching" (progress bar/ring) or "countdown" (live timer to `targetDate`).
        var mode: String
        /// 0…1 watch progress (watching mode).
        var progress: Double
        /// e.g. "S2 E3 · 24 min left" or "Movie night".
        var subtitle: String
        /// Short verb shown in the Dynamic Island, e.g. "Watching" / "Starts soon".
        var statusText: String
        /// The moment being counted down to (countdown mode) — powers the auto-ticking
        /// on-device timer with no push updates required.
        var targetDate: Date?

        var isCountdown: Bool { mode == "countdown" }
    }

    /// Static metadata for the whole activity (doesn't change).
    var title: String
    var mediaKind: String   // "movie" | "tv"
    var posterPath: String?
    var tmdbId: Int
}

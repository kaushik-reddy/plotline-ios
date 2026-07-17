import ActivityKit
import SwiftUI

/// Starts, updates and ends Live Activities (Dynamic Island + Lock Screen). Local ActivityKit
/// requests — no push server required. One activity per title (keyed by tmdbId). Supports both
/// a "watching" progress activity and a "countdown" timer activity (e.g. a scheduled watch
/// starting in 30 minutes).
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// tmdbId → running activity.
    private var activities: [Int: Activity<WatchActivityAttributes>] = [:]

    private init() {}

    /// Whether the user has Live Activities enabled for this app in Settings.
    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func isActive(_ id: Int) -> Bool { activities[id] != nil }

    /// Reconnect to any activities still running from a previous launch.
    func syncRunning() {
        for activity in Activity<WatchActivityAttributes>.activities {
            activities[activity.attributes.tmdbId] = activity
        }
    }

    // MARK: Core

    /// Start a new activity or update the existing one for a title (mode can change between
    /// "watching" and "countdown" via the content state).
    func apply(title: String, media: MediaKind, id: Int, posterPath: String?, state: WatchActivityAttributes.ContentState) {
        if let activity = activities[id] {
            let content = ActivityContent(state: state, staleDate: state.targetDate)
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WatchActivityAttributes(title: title, mediaKind: media.rawValue, posterPath: posterPath, tmdbId: id)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: state.targetDate)
            )
            activities[id] = activity
        } catch {
            #if DEBUG
            print("Live Activity start failed: \(error)")
            #endif
        }
    }

    // MARK: Convenience

    /// Start/update a "now watching" activity with a progress bar.
    func start(title: String, media: MediaKind, id: Int, posterPath: String?, progress: Double, subtitle: String, status: String = "Watching") {
        apply(title: title, media: media, id: id, posterPath: posterPath,
              state: .init(mode: "watching", progress: progress, subtitle: subtitle, statusText: status, targetDate: nil))
    }

    /// Start/update a "countdown" activity that live-ticks down to `targetDate` (a scheduled watch).
    func startCountdown(title: String, media: MediaKind, id: Int, posterPath: String?, targetDate: Date, subtitle: String) {
        apply(title: title, media: media, id: id, posterPath: posterPath,
              state: .init(mode: "countdown", progress: 0, subtitle: subtitle, statusText: "Starts soon", targetDate: targetDate))
    }

    func update(id: Int, progress: Double, subtitle: String, status: String = "Watching") async {
        guard let activity = activities[id] else { return }
        let state = WatchActivityAttributes.ContentState(mode: "watching", progress: progress, subtitle: subtitle, statusText: status, targetDate: nil)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end(id: Int) async {
        guard let activity = activities[id] else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activities[id] = nil
    }

    func endAll() async {
        for (id, activity) in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            activities[id] = nil
        }
    }
}

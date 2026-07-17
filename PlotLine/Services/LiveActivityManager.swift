import ActivityKit
import SwiftUI

/// Starts, updates and ends "now watching" Live Activities (Dynamic Island + Lock Screen).
/// Uses local ActivityKit requests — no push server required. One activity per title.
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// tmdbId → running activity.
    private var activities: [Int: Activity<WatchActivityAttributes>] = [:]

    private init() {}

    /// Whether the user has Live Activities enabled for this app in Settings.
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isActive(_ id: Int) -> Bool { activities[id] != nil }

    /// Reconnect to any activities still running from a previous launch.
    func syncRunning() {
        for activity in Activity<WatchActivityAttributes>.activities {
            activities[activity.attributes.tmdbId] = activity
        }
    }

    /// Start (or replace) the Live Activity for a title.
    @discardableResult
    func start(title: String, media: MediaKind, id: Int, posterPath: String?, progress: Double, subtitle: String, status: String = "Watching") -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        // Don't stack duplicates.
        if activities[id] != nil { return true }

        let attributes = WatchActivityAttributes(title: title, mediaKind: media.rawValue, posterPath: posterPath, tmdbId: id)
        let state = WatchActivityAttributes.ContentState(progress: progress, subtitle: subtitle, statusText: status)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            activities[id] = activity
            return true
        } catch {
            #if DEBUG
            print("Live Activity start failed: \(error)")
            #endif
            return false
        }
    }

    /// Push a new progress/subtitle to a running activity.
    func update(id: Int, progress: Double, subtitle: String, status: String = "Watching") async {
        guard let activity = activities[id] else { return }
        let state = WatchActivityAttributes.ContentState(progress: progress, subtitle: subtitle, statusText: status)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    /// End and dismiss the activity for a title.
    func end(id: Int) async {
        guard let activity = activities[id] else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activities[id] = nil
    }

    /// End every running activity (e.g. on sign-out).
    func endAll() async {
        for (id, activity) in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            activities[id] = nil
        }
    }
}

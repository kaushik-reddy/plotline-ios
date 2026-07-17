import UserNotifications

/// Local notifications for episode drops and scheduled watches — "live" reminders that fire
/// on the Lock Screen even when the app is closed. No push server required.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Ask once for permission to show alerts, sounds and badges.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedule a one-off reminder. Identifiers are stable per title so re-scheduling
    /// replaces rather than duplicates. Past dates are ignored.
    func schedule(id: String, title: String, body: String, at date: Date) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "pl_\(id)", content: content, trigger: trigger)
        center.add(request)
    }

    /// Remove a previously scheduled reminder.
    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["pl_\(id)"])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}

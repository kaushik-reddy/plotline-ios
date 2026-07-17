import SwiftUI

/// A live-ticking "in Xd Yh Zm Ws" countdown to a target date, matching the web app's
/// planned/calendar countdowns. Updates every second via `TimelineView`.
struct CountdownText: View {
    let target: Date
    var prefix: String = "in "

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(label(now: context.date))
                .monospacedDigit()
        }
    }

    private func label(now: Date) -> String {
        let total = max(0, Int(target.timeIntervalSince(now)))
        if total == 0 { return "now" }
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if d > 0 { return "\(prefix)\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(prefix)\(h)h \(m)m \(s)s" }
        return "\(prefix)\(m)m \(s)s"
    }
}

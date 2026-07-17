import ActivityKit
import WidgetKit
import SwiftUI

/// PlotLine Live Activity — renders on the Lock Screen, as a banner, and in every Dynamic
/// Island presentation. Supports two modes driven by `WatchActivityAttributes.ContentState`:
///  • "watching"  → a progress ring/bar for what you're currently watching.
///  • "countdown" → a live auto-ticking timer to a scheduled watch (e.g. starts in 30 min).
struct WatchLiveActivity: Widget {
    private static let orange = Color(red: 0xF4 / 255, green: 0x74 / 255, blue: 0x21 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WatchActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.mediaKind == "tv" ? "tv.fill" : "film.fill")
                        .font(.title3)
                        .foregroundStyle(Self.orange)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isCountdown, let target = context.state.targetDate {
                        Text(timerInterval: Self.range(to: target), countsDown: true)
                            .font(.headline).monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 74)
                            .foregroundStyle(Self.orange)
                            .padding(.trailing, 4)
                    } else {
                        Text("\(Int((context.state.progress * 100).rounded()))%")
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(Self.orange)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.subheadline).bold()
                            .lineLimit(1)
                        Text((context.state.isCountdown ? "Starts soon" : context.state.statusText).uppercased())
                            .font(.caption2).bold()
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if context.state.isCountdown, let target = context.state.targetDate {
                            ProgressView(timerInterval: Self.range(to: target), countsDown: true) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(Self.orange)
                        } else {
                            ProgressView(value: max(0, min(context.state.progress, 1)))
                                .tint(Self.orange)
                        }
                        Text(context.state.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.state.isCountdown ? "clock.fill" : "play.fill")
                    .foregroundStyle(Self.orange)
            } compactTrailing: {
                if context.state.isCountdown, let target = context.state.targetDate {
                    Text(timerInterval: Self.range(to: target), countsDown: true)
                        .font(.caption2).monospacedDigit()
                        .frame(maxWidth: 54)
                        .foregroundStyle(Self.orange)
                } else {
                    Text("\(Int((context.state.progress * 100).rounded()))%")
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle(Self.orange)
                }
            } minimal: {
                Image(systemName: context.state.isCountdown ? "clock.fill" : "play.fill")
                    .foregroundStyle(Self.orange)
            }
            .widgetURL(URL(string: "plotline://title/\(context.attributes.mediaKind)/\(context.attributes.tmdbId)"))
            .keylineTint(Self.orange)
        }
    }

    /// A safe timer range ending at `target` (never empty/backwards).
    static func range(to target: Date) -> ClosedRange<Date> {
        let start = min(Date(), target)
        let end = max(target, start.addingTimeInterval(1))
        return start...end
    }
}

/// Lock Screen / banner layout, mode-aware.
private struct LockScreenView: View {
    let context: ActivityViewContext<WatchActivityAttributes>
    private var orange: Color { Color(red: 0xF4 / 255, green: 0x74 / 255, blue: 0x21 / 255) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.isCountdown ? "clock.fill" : (context.attributes.mediaKind == "tv" ? "tv.fill" : "film.fill"))
                .font(.title2)
                .foregroundStyle(orange)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    if context.state.isCountdown, let target = context.state.targetDate {
                        Text(timerInterval: WatchLiveActivity.range(to: target), countsDown: true)
                            .font(.subheadline).bold().monospacedDigit()
                            .frame(maxWidth: 84)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(orange)
                    } else {
                        Text("\(Int((context.state.progress * 100).rounded()))%")
                            .font(.subheadline).bold().monospacedDigit()
                            .foregroundStyle(orange)
                    }
                }
                if context.state.isCountdown, let target = context.state.targetDate {
                    ProgressView(timerInterval: WatchLiveActivity.range(to: target), countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(orange)
                } else {
                    ProgressView(value: max(0, min(context.state.progress, 1)))
                        .tint(orange)
                }
                Text(context.state.isCountdown ? "Starts soon · \(context.state.subtitle)" : context.state.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

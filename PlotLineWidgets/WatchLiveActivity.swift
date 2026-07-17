import ActivityKit
import WidgetKit
import SwiftUI

/// PlotLine "now watching" Live Activity — renders on the Lock Screen, as a banner, and in
/// every Dynamic Island presentation (compact, minimal, expanded). Driven by
/// `WatchActivityAttributes` which the app updates as you watch.
struct WatchLiveActivity: Widget {
    // Brand orange (matches the app's #f47421).
    private static let orange = Color(red: 0xF4 / 255, green: 0x74 / 255, blue: 0x21 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WatchActivityAttributes.self) { context in
            // MARK: Lock Screen / banner presentation
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            // MARK: Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.mediaKind == "tv" ? "tv.fill" : "film.fill")
                        .font(.title3)
                        .foregroundStyle(Self.orange)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int((context.state.progress * 100).rounded()))%")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Self.orange)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.subheadline).bold()
                            .lineLimit(1)
                        Text(context.state.statusText.uppercased())
                            .font(.caption2).bold()
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: max(0, min(context.state.progress, 1)))
                            .tint(Self.orange)
                        Text(context.state.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "play.fill")
                    .foregroundStyle(Self.orange)
            } compactTrailing: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(Self.orange)
            } minimal: {
                Image(systemName: "play.fill")
                    .foregroundStyle(Self.orange)
            }
            .widgetURL(URL(string: "plotline://title/\(context.attributes.mediaKind)/\(context.attributes.tmdbId)"))
            .keylineTint(Self.orange)
        }
    }
}

/// Lock Screen / banner layout for the Live Activity.
private struct LockScreenView: View {
    let context: ActivityViewContext<WatchActivityAttributes>
    private var orange: Color { Color(red: 0xF4 / 255, green: 0x74 / 255, blue: 0x21 / 255) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.attributes.mediaKind == "tv" ? "tv.fill" : "film.fill")
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
                    Text("\(Int((context.state.progress * 100).rounded()))%")
                        .font(.subheadline).bold().monospacedDigit()
                        .foregroundStyle(orange)
                }
                ProgressView(value: max(0, min(context.state.progress, 1)))
                    .tint(orange)
                Text(context.state.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

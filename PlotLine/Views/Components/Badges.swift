import SwiftUI

/// Small colored status chip (dot + label) shown on library titles — matches the web
/// app's status pills using the shared STATUS_META colors.
struct StatusPill: View {
    let status: LibStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            if !compact {
                Text(status.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 4 : 5)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(status.color.opacity(0.5), lineWidth: 1))
    }
}

/// Gold star + rating value badge (bottom-left of poster cards), like the web Explore cards.
struct RatingBadge: View {
    let value: Double?

    var body: some View {
        if let value, value > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.gold)
                Text(String(format: "%.1f", value))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
        }
    }
}

/// Section header used across rails/screens: an orange uppercase kicker style label.
struct SectionHeader: View {
    let title: String
    var kicker: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let kicker {
                Text(kicker.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(Theme.orange)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }
}

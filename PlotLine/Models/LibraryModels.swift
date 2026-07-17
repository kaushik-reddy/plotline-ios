import SwiftUI

/// Library status, matching the web app's `Status` union and `STATUS_META` colors.
enum LibStatus: String, Codable, CaseIterable, Identifiable {
    case watchlist
    case scheduled
    case watching
    case caughtup
    case onhold
    case dropped
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watchlist: return "Watchlist"
        case .scheduled: return "Scheduled"
        case .watching: return "Watching"
        case .caughtup: return "Caught Up"
        case .onhold: return "On Hold"
        case .dropped: return "Dropped"
        case .completed: return "Completed"
        }
    }

    var color: Color {
        switch self {
        case .watchlist: return Color(hex: 0x9AA0AA)
        case .scheduled: return Theme.orange
        case .watching: return Theme.blue
        case .caughtup: return Theme.teal
        case .onhold: return Theme.amber
        case .dropped: return Theme.red
        case .completed: return Theme.green
        }
    }

    /// Order shown in status pickers / Binge tabs (matches STATUS_ORDER).
    static let order: [LibStatus] = [.watchlist, .scheduled, .watching, .caughtup, .onhold, .dropped, .completed]
}

/// A single library entry. Mirrors the web app's `LibEntry` (persisted under the
/// same `pl_lib_overrides` shape so cross-device sync stays compatible).
struct LibEntry: Codable, Identifiable, Hashable {
    var media: MediaKind
    var id: String
    var status: LibStatus
    var scheduledAt: Double?   // epoch ms, when status == .scheduled
    var scheduledSub: String?

    var key: String { media.rawValue + ":" + id }
}

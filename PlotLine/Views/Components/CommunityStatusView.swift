import SwiftUI

/// "Where fans are" — a deterministic community status leaderboard, ported from the web
/// `CommunityStatus.tsx`. Counts are synthesized per title (stable hash → seeded RNG) since
/// there's no social backend; your own status is highlighted.
struct CommunityStatusView: View {
    let media: MediaKind
    let id: Int
    let voteCount: Int
    @Environment(LibraryStore.self) private var library

    private var ranked: [(status: LibStatus, count: Int)] {
        var next = Self.rng(Self.hash("\(media.rawValue):\(id)"))
        let base = 180.0 + Double(voteCount) * 1.4
        let weights: [(LibStatus, Double)] = [
            (.watchlist, 0.12), (.scheduled, 0.06), (.watching, 0.22),
            (.caughtup, 0.10), (.onhold, 0.06), (.dropped, 0.06), (.completed, 0.38),
        ]
        return weights
            .map { (status, w) in (status, Int((base * w * (0.7 + 0.6 * next())).rounded())) }
            .sorted { $0.1 > $1.1 }
    }

    private var total: Int { ranked.reduce(0) { $0 + $1.count } }
    private var maxCount: Int { ranked.map(\.count).max() ?? 1 }
    private var mine: LibStatus? { library.entry(media, id)?.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Where fans are", kicker: "\(total) tracking")
            if let top = ranked.first {
                HStack(spacing: 6) {
                    Circle().fill(top.status.color).frame(width: 8, height: 8)
                    (Text("Most fans are ").foregroundColor(Theme.muted)
                        + Text(top.status.label).foregroundColor(Theme.text).bold()
                        + Text(" · \(pct(top.count))%").foregroundColor(Theme.muted))
                        .font(.system(size: 13))
                }
            }
            VStack(spacing: 10) {
                ForEach(ranked, id: \.status) { row in
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Circle().fill(row.status.color).frame(width: 7, height: 7)
                            Text(row.status.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                        }
                        .frame(width: 92, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.panelRaised)
                                Capsule().fill(row.status.color)
                                    .frame(width: max(4, geo.size.width * CGFloat(row.count) / CGFloat(maxCount)))
                            }
                        }
                        .frame(height: 9)
                        Text("\(row.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 36, alignment: .trailing)
                        if mine == row.status {
                            Text("You").font(.system(size: 10, weight: .bold)).foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(row.status.color, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func pct(_ n: Int) -> Int { total > 0 ? Int((Double(n) / Double(total) * 100).rounded()) : 0 }

    // Deterministic hash + xorshift RNG (mirrors the web mulberry32 approach closely enough).
    private static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }
    private static func rng(_ seed: UInt64) -> () -> Double {
        var s = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        return {
            s ^= s << 13; s ^= s >> 7; s ^= s << 17
            return Double(s % 1_000_000) / 1_000_000.0
        }
    }
}

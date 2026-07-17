import SwiftUI

/// Country / region, ported from the web app's `region.ts`. Drives watch-provider
/// region and date/time display. Persisted under `pl_country` for sync compatibility.
@Observable
final class RegionStore {
    static let shared = RegionStore()

    struct Country: Identifiable, Hashable {
        let code: String
        let name: String
        let tz: String
        var id: String { code }
    }

    /// A trimmed list covering the common regions used by the web app.
    static let countries: [Country] = [
        Country(code: "US", name: "United States", tz: "America/New_York"),
        Country(code: "IN", name: "India", tz: "Asia/Kolkata"),
        Country(code: "GB", name: "United Kingdom", tz: "Europe/London"),
        Country(code: "CA", name: "Canada", tz: "America/Toronto"),
        Country(code: "AU", name: "Australia", tz: "Australia/Sydney"),
        Country(code: "DE", name: "Germany", tz: "Europe/Berlin"),
        Country(code: "FR", name: "France", tz: "Europe/Paris"),
        Country(code: "JP", name: "Japan", tz: "Asia/Tokyo"),
        Country(code: "KR", name: "South Korea", tz: "Asia/Seoul"),
        Country(code: "BR", name: "Brazil", tz: "America/Sao_Paulo"),
        Country(code: "ES", name: "Spain", tz: "Europe/Madrid"),
        Country(code: "IT", name: "Italy", tz: "Europe/Rome"),
    ]

    private let lsKey = "pl_country"
    private(set) var code: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: lsKey)
        // Default to the device's region if we recognize it, else IN (web default).
        let device = Locale.current.region?.identifier
        code = saved ?? (Self.countries.contains(where: { $0.code == device }) ? device! : "IN")
    }

    var country: Country {
        Self.countries.first { $0.code == code } ?? Self.countries[1]
    }

    func setCountry(_ code: String) {
        self.code = code
        UserDefaults.standard.set(code, forKey: lsKey)
        SyncService.shared.markDirty()
    }
}

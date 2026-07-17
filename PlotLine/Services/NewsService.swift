import Foundation

/// A movie/TV news article from the PlotLine `/api/news` aggregator (same source the web app's
/// News reader uses — free entertainment RSS feeds combined server-side).
struct NewsItem: Codable, Identifiable, Hashable {
    let title: String
    let link: String
    let source: String?
    let image: String?
    let description: String?
    let pubDate: String?

    var id: String { link }
}

/// Fetches the aggregated news feed.
enum NewsService {
    private static let endpoint = "https://func-svc-gor9cs.azurewebsites.net/api/news"

    static func fetch() async -> [NewsItem] {
        guard let url = URL(string: endpoint) else { return [] }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
            return (try? JSONDecoder().decode([NewsItem].self, from: data)) ?? []
        } catch {
            return []
        }
    }
}

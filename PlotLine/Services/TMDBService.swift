import Foundation

/// Client for the PlotLine TMDB proxy — the exact same Azure Function used by the web
/// app. The proxy hides the TMDB key and bypasses ISP DNS blocking; no credentials
/// live in the client. Extra query is forwarded via the proxy's `&q=` param and
/// responses are cached in memory for 10 minutes (mirrors the web client).
actor TMDBService {
    static let shared = TMDBService()

    private let proxy = "https://func-svc-gor9cs.azurewebsites.net/api/tmdb"
    private static let imgProxy = "https://func-svc-gor9cs.azurewebsites.net/api/img"

    private let ttl: TimeInterval = 10 * 60
    private var cache: [String: (t: Date, data: Data)] = [:]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    /// Build an image URL routed through our own Blob mirror so images keep working
    /// even if TMDB's CDN changes. `nonisolated` + `static` so views can call it
    /// synchronously. Common sizes: w92, w185, w300, w500, w780, original.
    nonisolated static func img(_ size: String, _ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let escaped = path.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? path
        return URL(string: "\(imgProxy)?size=\(size)&path=\(escaped)")
    }

    /// Fetch and decode a TMDB path through the proxy.
    /// - Parameters:
    ///   - path: e.g. "/tv/1396" or "/movie/popular".
    ///   - q: extra query string forwarded via the proxy (e.g. "append_to_response=credits").
    ///   - fresh: bypass the cache and pull live data.
    func get<T: Decodable>(_ path: String, q: String? = nil, fresh: Bool = false, as type: T.Type) async -> T? {
        guard let data = await raw(path, q: q, fresh: fresh) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("TMDB decode error for \(path): \(error)")
            #endif
            return nil
        }
    }

    private func raw(_ path: String, q: String?, fresh: Bool) async -> Data? {
        var comps = URLComponents(string: proxy)!
        var items = [URLQueryItem(name: "path", value: path)]
        if let q { items.append(URLQueryItem(name: "q", value: q)) }
        comps.queryItems = items
        guard let url = comps.url else { return nil }
        let key = url.absoluteString

        if !fresh, let hit = cache[key], Date().timeIntervalSince(hit.t) < ttl {
            return hit.data
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return cache[key]?.data // serve any stale copy on error (resilience)
            }
            cache[key] = (Date(), data)
            return data
        } catch {
            return cache[key]?.data
        }
    }
}

extension CharacterSet {
    /// Percent-encoding set safe for a URL query value (encodes `/`, `=`, `&`, etc.).
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "/=&?+#")
        return set
    }()
}

import SwiftUI

/// Cross-device sync. All personal state lives under `pl_*` keys in `UserDefaults`;
/// this service mirrors that whole set to the same Azure `/api/state` blob the web app
/// uses, keyed by a user-chosen "sync code". Enter the same code on another device (or
/// on the website) to load the same data. Last-write-wins on a single JSON document.
@Observable
final class SyncService {
    static let shared = SyncService()

    enum Status { case idle, syncing, synced, offline, error }

    private let api = "https://func-svc-gor9cs.azurewebsites.net/api/state"
    private let codeKey = "pl_sync_code"
    private let verKey = "pl_sync_updatedAt"
    /// Keys owned by the sync engine or iOS-internal — never mirrored to the cloud.
    private let ownKeys: Set<String> = ["pl_sync_code", "pl_sync_updatedAt", "pl_ratings_ios"]

    private(set) var status: Status = .idle
    private(set) var lastSyncAt: Date?
    private(set) var code: String?

    private var pushTask: Task<Void, Never>?
    private var applying = false

    private init() {
        code = UserDefaults.standard.string(forKey: codeKey)
    }

    var isLinked: Bool { code != nil }

    /// A friendly, hard-to-guess code like `plum-tiger-4821` (same scheme as the web app).
    func generateCode() -> String {
        let adj = ["amber","brisk","calm","dusk","ember","fable","glide","haze","ivory","jade","lumen","maple","nova","onyx","plum","quill","rustic","slate","tidal","umber","vivid","wisp"]
        let noun = ["badger","comet","cinder","delta","falcon","grove","harbor","iris","jetty","koi","lark","meadow","nimbus","otter","pines","quartz","raven","summit","tiger","vale","willow","zephyr"]
        let n = 1000 + Int.random(in: 0..<9000)
        return "\(adj.randomElement()!)-\(noun.randomElement()!)-\(n)"
    }

    // MARK: Linking

    /// Start syncing this device under `code`, pulling remote data (remote wins if present).
    @MainActor
    @discardableResult
    func connect(_ raw: String) async -> Bool {
        let c = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !c.isEmpty else { return false }
        code = c
        UserDefaults.standard.set(c, forKey: codeKey)
        UserDefaults.standard.set(0.0, forKey: verKey) // force next pull to accept remote
        let result = await pull()
        if result == .empty { await push() } // seed the cloud from this device
        return result != .error
    }

    @MainActor
    func disconnect() {
        code = nil
        UserDefaults.standard.removeObject(forKey: codeKey)
        status = .idle
    }

    @MainActor
    func pullIfLinked() async {
        guard isLinked else { return }
        await pull()
    }

    // MARK: Debounced push

    /// Called by every store after a local write. Debounced ~1.2s.
    func markDirty() {
        guard isLinked, !applying else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    // MARK: Pull / Push

    enum PullResult { case applied, nochange, empty, error }

    @MainActor
    @discardableResult
    func pull() async -> PullResult {
        guard let code else { return .error }
        status = .syncing
        guard var comps = URLComponents(string: api) else { status = .error; return .error }
        comps.queryItems = [URLQueryItem(name: "code", value: code)]
        guard let url = comps.url else { status = .error; return .error }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { status = .error; return .error }
            guard let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = doc["payload"] as? String else {
                status = .synced; return .empty
            }
            let remoteVer = (doc["updatedAt"] as? Double) ?? 0
            if remoteVer <= UserDefaults.standard.double(forKey: verKey) {
                status = .synced; return .nochange
            }
            guard let pData = payload.data(using: .utf8),
                  let map = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                status = .error; return .error
            }
            applySnapshot(map)
            UserDefaults.standard.set(remoteVer, forKey: verKey)
            status = .synced
            lastSyncAt = Date()
            return .applied
        } catch {
            status = .offline
            return .error
        }
    }

    @MainActor
    @discardableResult
    func push() async -> Bool {
        guard let code else { return false }
        let updatedAt = Date().timeIntervalSince1970 * 1000
        let payload = collect()
        guard let payloadStr = jsonString(payload),
              let body = try? JSONSerialization.data(withJSONObject: ["payload": payloadStr, "updatedAt": updatedAt]),
              var comps = URLComponents(string: api) else { return false }
        comps.queryItems = [URLQueryItem(name: "code", value: code)]
        guard let url = comps.url else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type") // simple CORS request
        req.httpBody = body
        status = .syncing
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { status = .error; return false }
            UserDefaults.standard.set(updatedAt, forKey: verKey)
            status = .synced
            lastSyncAt = Date()
            return true
        } catch {
            status = .offline
            return false
        }
    }

    // MARK: Snapshot I/O

    /// Collect all mirrored `pl_*` keys as strings (matching the web's localStorage values).
    private func collect() -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in UserDefaults.standard.dictionaryRepresentation() {
            guard k.hasPrefix("pl_"), !ownKeys.contains(k) else { continue }
            if let s = v as? String {
                out[k] = s
            } else if let n = v as? NSNumber {
                out[k] = n.stringValue
            }
        }
        return out
    }

    private func applySnapshot(_ data: [String: Any]) {
        applying = true
        let defaults = UserDefaults.standard
        // Remove local pl_* string keys no longer present remotely (full-document replace).
        for (k, v) in defaults.dictionaryRepresentation() {
            guard k.hasPrefix("pl_"), !ownKeys.contains(k) else { continue }
            if (v is String || v is NSNumber), data[k] == nil {
                defaults.removeObject(forKey: k)
            }
        }
        for (k, v) in data {
            if let s = v as? String { defaults.set(s, forKey: k) }
            else if let n = v as? NSNumber { defaults.set(n.stringValue, forKey: k) }
        }
        applying = false
        // Rehydrate reactive stores.
        LibraryStore.shared.rehydrate()
        ProgressStore.shared.rehydrate()
        RatingStore.shared.rehydrate()
        CommentsStore.shared.rehydrate()
        RewatchStore.shared.rehydrate()
        PostersStore.shared.rehydrate()
        ReviewsStore.shared.rehydrate()
    }

    private func jsonString(_ obj: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

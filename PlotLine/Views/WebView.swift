import SwiftUI
import UIKit
import WebKit

/// Lightweight controller so SwiftUI can drive an existing `WKWebView` (reload, navigate).
@Observable
final class WebController {
    weak var webView: WKWebView?
    func reload() { webView?.reload() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
}

/// A full-screen wrapper around `WKWebView` that renders the **actual deployed PlotLine web
/// app** — a true pixel-for-pixel replica, since it is the same HTML/CSS/JS the website
/// serves. A JavaScript bridge (`window.PlotLineNative`) lets the web content drive native
/// iOS features: Live Activities (Dynamic Island + Lock Screen) and local notifications.
struct WebView: UIViewRepresentable {
    let url: URL
    let controller: WebController
    @Binding var isLoading: Bool
    @Binding var loadError: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default() // persist the site's localStorage (library, sync code, …)

        let content = WKUserContentController()
        content.add(context.coordinator, name: "plotline")
        content.addUserScript(WKUserScript(source: Self.fitJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = content

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = UIColor(Theme.bg)
        web.scrollView.backgroundColor = UIColor(Theme.bg)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.showsVerticalScrollIndicator = false
        web.scrollView.showsHorizontalScrollIndicator = false
        // Lock zoom so a title page can never render "widened" / zoomed-out.
        web.scrollView.minimumZoomScale = 1
        web.scrollView.maximumZoomScale = 1
        web.scrollView.bouncesZoom = false

        controller.webView = web
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    // MARK: Bridge script injected into the page

    /// Keeps the web app locked to the device width so title pages never render "widened".
    /// Hardens the viewport (no user zoom) and clips any accidental horizontal overflow at the
    /// React root using `overflow-x: clip`, which — unlike `hidden` — does not break the site's
    /// `position: fixed`/`sticky` headers.
    private static let fitJS = """
    (function () {
      function setViewport() {
        var m = document.querySelector('meta[name=viewport]');
        if (!m) {
          m = document.createElement('meta');
          m.setAttribute('name', 'viewport');
          (document.head || document.documentElement).appendChild(m);
        }
        m.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover');
      }
      function addStyle() {
        var css = 'html,body{max-width:100%;overflow-x:clip;-webkit-text-size-adjust:100%;}'
                + '#root{overflow-x:clip;max-width:100%;}'
                + 'img,video,svg{max-width:100%;}';
        var s = document.createElement('style');
        s.setAttribute('data-plotline-fit', '1');
        s.textContent = css;
        (document.head || document.documentElement).appendChild(s);
      }
      setViewport();
      addStyle();
      document.addEventListener('DOMContentLoaded', function () { setViewport(); addStyle(); });
    })();
    """

    /// Exposes `window.PlotLineNative.{startLiveActivity,updateLiveActivity,endLiveActivity,notify}`
    /// to the web app. Each call posts a JSON message to the native handler below.
    private static let bridgeJS = """
    (function () {
      function send(payload) {
        try { window.webkit.messageHandlers.plotline.postMessage(payload || {}); } catch (e) {}
      }
      window.PlotLineNative = {
        available: true,
        startLiveActivity: function (o) { send(Object.assign({ type: 'start' }, o || {})); },
        updateLiveActivity: function (o) { send(Object.assign({ type: 'update' }, o || {})); },
        endLiveActivity: function (o) { send(Object.assign({ type: 'end' }, o || {})); },
        notify: function (o) { send(Object.assign({ type: 'notify' }, o || {})); }
      };
    })();
    """

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        // Loading state
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = false
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if (error as NSError).code != NSURLErrorCancelled { parent.loadError = true }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if (error as NSError).code != NSURLErrorCancelled { parent.loadError = true }
        }

        // Keep same-site navigation in the web view; open external links in Safari.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                if url.host == nil || url.host == parent.url.host {
                    decisionHandler(.allow)
                } else {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                }
            } else {
                // mailto:, tel:, youtube:, etc.
                if UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
                decisionHandler(.cancel)
            }
        }

        // target="_blank" links (e.g. news articles) → load in the same web view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if url.host == parent.url.host {
                    webView.load(navigationAction.request)
                } else {
                    UIApplication.shared.open(url)
                }
            }
            return nil
        }

        // MARK: JS → native bridge (Live Activities + notifications)
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "plotline", let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            let id = (body["id"] as? Int) ?? Int((body["id"] as? String) ?? "") ?? 0
            let title = (body["title"] as? String) ?? "PlotLine"
            let media = MediaKind(rawValue: (body["media"] as? String) ?? "tv") ?? .tv
            let poster = body["posterPath"] as? String
            let progress = (body["progress"] as? Double) ?? 0
            let subtitle = (body["subtitle"] as? String) ?? ""
            let status = (body["status"] as? String) ?? "Watching"

            switch type {
            case "start":
                LiveActivityManager.shared.start(title: title, media: media, id: id,
                                                 posterPath: poster, progress: progress,
                                                 subtitle: subtitle, status: status)
            case "update":
                Task { await LiveActivityManager.shared.update(id: id, progress: progress, subtitle: subtitle, status: status) }
            case "end":
                Task { await LiveActivityManager.shared.end(id: id) }
            case "notify":
                let when = (body["at"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
                    ?? Date().addingTimeInterval(60)
                NotificationManager.shared.schedule(id: "\(media.rawValue)_\(id)", title: title, body: subtitle, at: when)
            default:
                break
            }
        }
    }
}

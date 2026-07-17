# PlotLine — iOS

An iPhone app (built for **iPhone Air, iOS 26**) that is a **true pixel-for-pixel replica**
of the [PlotLine web app](https://gentle-desert-01c503400.7.azurestaticapps.net). Rather than
re-implement (and risk missing) any of the website's screens, the app renders the **real
deployed web app** full-screen in a native `WKWebView`. It *is* the website — same layout,
same styles, same features, always up to date — wrapped in a native iOS 26 SwiftUI shell.

On top of that exact web experience, the app adds native iOS surfaces the browser can't:

- **Live Activities** — a “now watching” card on the **Lock Screen**.
- **Dynamic Island** — compact, minimal and expanded presentations with a live progress ring.
- **Local notifications** — Lock Screen reminders for tracked episodes / scheduled watches.

These are driven from the web content through a JavaScript bridge (`window.PlotLineNative`).

> Why a WebView? You asked for an exact, nothing-missing replica of the web version. A
> hand-written native re-build of ~1,800 web modules would inevitably drift from the site.
> Hosting the real web app guarantees 100% parity and that new website features appear on
> the phone automatically.

---

## What's inside

| Piece | Role |
|---|---|
| `RootWebView` / `WebView` | Full-screen `WKWebView` rendering the live PlotLine site (pixel-for-pixel), with a branded splash and offline retry. |
| `window.PlotLineNative` bridge | JS API injected into the page so the web app can start/update/end **Live Activities** and schedule **notifications** natively. |
| `PlotLineWidgets/` | Widget extension: the Live Activity UI for **Dynamic Island** + **Lock Screen**. |
| `LiveActivityManager` / `NotificationManager` | Native services the bridge calls into. |
| `PlotLine/Views/*` (native screens) | A hand-written native SwiftUI version of every screen — **kept in the repo** as a starting point, but not the shell. The WebView supersedes it for exact parity. |

---

## Wiring the web app to the native features (optional)

The bridge is ready; the deployed website just doesn't call it yet. To make Live Activities
fire automatically, add a few no-op-on-desktop calls in the web app, e.g. when a title
becomes “Watching”:

```js
// safe on every platform — only does something inside the iOS app
window.PlotLineNative?.startLiveActivity?.({
  id: 1396, media: 'tv', title: 'Breaking Bad',
  posterPath: '/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
  progress: 0.35, subtitle: 'S3 E5 · 24 min left', status: 'Watching'
})
// …later: window.PlotLineNative?.updateLiveActivity?.({ id: 1396, progress: 0.5, subtitle: '…' })
// …done:  window.PlotLineNative?.endLiveActivity?.({ id: 1396 })
```

I have the web source in the workspace, so I can add these hooks whenever you want.

---

## Getting it onto your Mac + GitHub

You're on the plan of *clone a repo and open it in Xcode*. Here's the one-time path:

### 1. Publish to GitHub (run once, on your Mac)

Copy this whole `plotline-ios` folder to your Mac, then in Terminal:

```bash
cd plotline-ios
chmod +x push-to-github.sh
./push-to-github.sh
```

That script creates a **new private repo** `kaushik-reddy/plotline-ios` and pushes
everything. It needs the GitHub CLI once:

```bash
brew install gh      # if you don't have Homebrew: https://brew.sh
gh auth login        # GitHub.com → HTTPS → login with browser
```

(If you'd rather not use `gh`, you can create an empty `plotline-ios` repo on github.com
and run: `git init -b main && git add -A && git commit -m "init" && git remote add origin

### 1. Publish to GitHub (run once, on your Mac)

Copy this whole `plotline-ios` folder to your Mac, then in Terminal:

```bash
cd plotline-ios
chmod +x push-to-github.sh
./push-to-github.sh
```

That script creates a **new private repo** `kaushik-reddy/plotline-ios` and pushes
everything. It needs the GitHub CLI once:

```bash
brew install gh      # if you don't have Homebrew: https://brew.sh
gh auth login        # GitHub.com → HTTPS → login with browser
```

(If you'd rather not use `gh`, you can create an empty `plotline-ios` repo on github.com
and run: `git init -b main && git add -A && git commit -m "init" && git remote add origin
https://github.com/kaushik-reddy/plotline-ios.git && git push -u origin main`.)

### 2. Open & run in Xcode

```bash
git clone https://github.com/kaushik-reddy/plotline-ios.git
cd plotline-ios
open PlotLine.xcodeproj
```

- In Xcode, select the **PlotLine** target → **Signing & Capabilities** → pick your
  personal Team (free Apple ID works).
- Choose an **iPhone 16 / iPhone Air simulator** (or your plugged-in iPhone) and press
  **⌘R**.

That's the "simple command each week" workflow you mentioned — after the first setup it's
just `git pull` + **⌘R**.

---

## Project layout

```
plotline-ios/
├─ PlotLine.xcodeproj/          # Xcode project (file-system synchronized — new files auto-compile)
├─ push-to-github.sh            # one-command publish to GitHub
├─ Shared/                      # code shared by app + widget (Live Activity attributes)
├─ PlotLineWidgets/             # widget extension: Live Activity + Dynamic Island UI + Info.plist
└─ PlotLine/
   ├─ PlotLineApp.swift         # @main entry, injects the shared stores
   ├─ Theme.swift               # colors ported from the web index.css tokens
   ├─ Assets.xcassets/          # accent color + app-icon slot
   ├─ Models/                   # TMDB Codable models + library models
   ├─ Services/                 # TMDB proxy client + stores + sync + Live Activity + notifications
   └─ Views/                    # RootTabView + Home/Explore/Calendar/Binge/Detail/Profile + Components
```

The project uses Xcode 16 **file-system synchronized groups**, so any `.swift` file added
under `PlotLine/` is compiled automatically — no need to fiddle with the project file.

---

## How it connects to your backend

- **Data:** every request goes through your existing Azure Function proxy
  `func-svc-gor9cs.azurewebsites.net/api/tmdb` (same one the website uses — the TMDB key
  stays server-side; nothing secret is in the app).
- **Images:** loaded through your image mirror `/api/img` for resilience.
- **Sync:** the Profile → *Cross-device Sync* card uses your `/api/state` endpoint. Enable
  sync to get a code (like `plum-tiger-4821`); enter the **same code** on another device —
  or on the website — to load the same library, progress and ratings. Last-write-wins on a
  single JSON document, keyed under the same `pl_*` keys as the web app.

No new Azure resources are required.

---

## Live Activities, Dynamic Island & notifications

- The **PlotLineWidgets** extension renders the Live Activity. On the title detail page tap
  **Track on Lock Screen** to start it; it appears on the Lock Screen and in the Dynamic
  Island (tap **Stop Live Activity** to end it). No entitlement or server is required — these
  are local ActivityKit activities.
- **Requirements:** a device (or simulator) running **iOS 26**, with a Dynamic Island device
  (iPhone 15 Pro / iPhone 16 / iPhone Air family) to see the island presentations. Live
  Activities must be enabled in **Settings ▸ PlotLine**.
- **Notifications:** the app requests permission on first launch and schedules reminders for
  your upcoming Calendar events.

## Updating (the weekly one-liner)

After the first setup you never re-clone. To get new code and reinstall:

```bash
cd plotline-ios
git pull
```

Then back in Xcode press **⌘R**. (Xcode auto-reloads the project when `git pull` changes it —
if it prompts, choose *Revert*/*Keep Xcode version* to accept the pulled project file.)

## Notes & next steps

- **App icon:** the `AppIcon` slot is empty (the app builds and runs fine without one). Drop
  a 1024×1024 PNG into `PlotLine/Assets.xcassets/AppIcon.appiconset` when you want a real icon.
- **Weekly rebuild reminder:** a free Apple ID signs apps for 7 days. To reinstall on your
  device, just `git pull` and **⌘R** again — that's the weekly one-liner.
- Built to grow: the per-episode Season playground, notes, reviews and the social feed from
  the web app are natural next additions on top of the stores already wired here.

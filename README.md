# PlotLine — iOS

A native **SwiftUI** app for iPhone (built for iPhone Air, iOS 17+) that mirrors the
[PlotLine web app](https://gentle-desert-01c503400.7.azurestaticapps.net): a personal
movie & TV tracker. Same dark theme and orange accent, same data — it talks to the exact
same TMDB proxy the website uses, and can sync your library across devices (and with the
website) using a sync code.

> This is a fresh, hand-written SwiftUI port — not a webview wrapper. Every screen is
> real native UI, so it feels like an iOS app, not a website in a box.

---

## What's inside

| Screen | What it does |
|---|---|
| **Home** | Continue Watching rail (live progress), Up Next (your planned titles), Trending / In Theaters / Popular Series discovery rails. |
| **Explore** | Search (`/search/multi`) + browse rails: Trending, Popular Movies/Series, Top Rated, On The Air, Upcoming. |
| **Calendar** | *My Calendar* (your scheduled titles + tracked shows' next episodes) and *Coming Soon* (upcoming movies), grouped by day. |
| **Binge** | Your library — filter by media (All / Movies / Shows) and by status, with counts. |
| **Title detail** | Cinematic hero, meta, TMDb + your PlotLine rating, Add Status, Rate, Seasons, Cast, Recommendations & Similar. |
| **Profile** | Identity, library stats & breakdown, **cross-device sync** card, and region/timezone picker. |

Statuses, colors and the `pl_*` storage keys match the web app, so your data stays
consistent everywhere.

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
└─ PlotLine/
   ├─ PlotLineApp.swift         # @main entry, injects the shared stores
   ├─ Theme.swift               # colors ported from the web index.css tokens
   ├─ Assets.xcassets/          # accent color + app-icon slot
   ├─ Models/                   # TMDB Codable models + library models
   ├─ Services/                 # TMDB proxy client + reactive stores + cross-device sync
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

## Notes & next steps

- **App icon:** the `AppIcon` slot is empty (the app builds and runs fine without one). Drop
  a 1024×1024 PNG into `PlotLine/Assets.xcassets/AppIcon.appiconset` when you want a real icon.
- **Weekly rebuild reminder:** a free Apple ID signs apps for 7 days. To reinstall on your
  device, just `git pull` and **⌘R** again — that's the weekly one-liner.
- Built to grow: the per-episode Season playground, notes, reviews and the social feed from
  the web app are natural next additions on top of the stores already wired here.

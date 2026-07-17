import SwiftUI
import UIKit

/// Marker route for the Profile screen (reached via the avatar in the header, like the web app).
struct ProfileRoute: Hashable {}

/// Root shell: a dark-themed bottom tab bar (Home, Explore, Calendar, Binge) — the four
/// primary destinations from the web app's top nav. Profile is reached via the header avatar.
struct RootTabView: View {
    init() {
        // Match the site: opaque near-black bars, orange selection.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bg)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.header)
        nav.shadowColor = UIColor(Theme.line)
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    var body: some View {
        TabView {
            PlotlineStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            PlotlineStack { ExploreView() }
                .tabItem { Label("Explore", systemImage: "sparkle.magnifyingglass") }
            PlotlineStack { CalendarView() }
                .tabItem { Label("Calendar", systemImage: "calendar") }
            PlotlineStack { BingeView() }
                .tabItem { Label("Binge", systemImage: "rectangle.stack.fill") }
        }
    }
}

/// A NavigationStack pre-wired with the PlotLine header (logo + profile avatar) and the
/// shared destinations (title detail + profile), so every tab shares consistent chrome.
struct PlotlineStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(ProfileStore_Avatar.self) private var avatar

    var body: some View {
        NavigationStack {
            content()
                .navigationDestination(for: TitleRef.self) { ref in
                    DetailView(media: ref.media, id: ref.id)
                }
                .navigationDestination(for: ProfileRoute.self) { _ in
                    ProfileView()
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("PLOTLINE")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(Theme.text)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: ProfileRoute()) {
                            AvatarView(seed: avatar.seed, size: 30)
                        }
                    }
                }
                .toolbarBackground(Theme.header, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

/// Deterministic circular avatar generated from a seed string. (AsyncImage can't render
/// DiceBear SVGs, so we draw a themed monogram that matches the dark UI.)
struct AvatarView: View {
    let seed: String
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(Theme.panelRaised)
            Text(String(seed.prefix(1)).uppercased())
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(Theme.orange)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.lineStrong, lineWidth: 2))
    }
}

/// Tiny store holding the user's avatar seed + display name (persisted, mirrors web `pl_profile`).
@Observable
final class ProfileStore_Avatar {
    static let shared = ProfileStore_Avatar()
    private let key = "pl_profile_ios"
    var seed: String { didSet { save() } }
    var name: String { didSet { save() } }

    private init() {
        let d = UserDefaults.standard
        seed = d.string(forKey: "\(key)_seed") ?? "Plotline"
        name = d.string(forKey: "\(key)_name") ?? "You"
    }
    private func save() {
        UserDefaults.standard.set(seed, forKey: "\(key)_seed")
        UserDefaults.standard.set(name, forKey: "\(key)_name")
    }
}

import SwiftUI

/// Profile — identity, library stats, cross-device sync and region settings. Mirrors the
/// web Profile/Settings: a header, a status breakdown, the sync card, and a country picker.
struct ProfileView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(RegionStore.self) private var region
    @Environment(SyncService.self) private var sync
    @Environment(ProfileStore_Avatar.self) private var avatar

    @State private var connectCode = ""
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statsGrid
                breakdown
                syncCard
                regionCard
                Color.clear.frame(height: 20)
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            AvatarView(seed: avatar.seed, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(avatar.name).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
                Text("PlotLine member").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            stat("\(library.entries.count)", "Tracked")
            stat("\(library.count(.watching))", "Watching")
            stat("\(library.count(.completed))", "Completed")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Library", kicker: "Breakdown")
            ForEach(LibStatus.order) { s in
                let c = library.count(s)
                if c > 0 {
                    HStack {
                        Circle().fill(s.color).frame(width: 9, height: 9)
                        Text(s.label).font(.system(size: 14)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(c)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Sync

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cross-device Sync", kicker: "Settings")

            if let code = sync.code {
                Text("Synced under code")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                HStack {
                    Text(code).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(Theme.orange)
                    Spacer()
                    syncStatusView
                }
                HStack(spacing: 10) {
                    actionButton("Sync now", filled: true) { Task { working = true; await sync.pull(); await sync.push(); working = false } }
                    actionButton("Stop syncing", filled: false) { sync.disconnect() }
                }
            } else {
                Text("Enter the same code on another device — or on the website — to mirror your whole library, progress and ratings.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                actionButton("Enable sync", filled: true) {
                    Task { working = true; _ = await sync.connect(sync.generateCode()); working = false }
                }
                HStack(spacing: 8) {
                    TextField("Have a code? Enter it", text: $connectCode)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .foregroundStyle(Theme.text)
                        .padding(10)
                        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                    Button("Link") {
                        Task { working = true; _ = await sync.connect(connectCode); connectCode = ""; working = false }
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                    .disabled(connectCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }

    private var syncStatusView: some View {
        Group {
            switch sync.status {
            case .syncing: HStack(spacing: 5) { ProgressView().controlSize(.mini).tint(Theme.orange); Text("Syncing") }
            case .synced: HStack(spacing: 5) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green); Text("Synced") }
            case .offline: HStack(spacing: 5) { Image(systemName: "wifi.slash").foregroundStyle(Theme.amber); Text("Offline") }
            case .error: HStack(spacing: 5) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.red); Text("Error") }
            case .idle: EmptyView()
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.muted)
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(filled ? Theme.orange : Theme.panelRaised, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(filled ? .clear : Theme.line, lineWidth: 1))
                .foregroundStyle(filled ? .black : Theme.text)
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    // MARK: Region

    private var regionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Region", kicker: "Settings")
            Picker("Country", selection: Binding(get: { region.code }, set: { region.setCountry($0) })) {
                ForEach(RegionStore.countries) { c in
                    Text(c.name).tag(c.code)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.orange)
            Text("Timezone: \(region.country.tz)")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line, lineWidth: 1))
    }
}

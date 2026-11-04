import SwiftUI

struct StepLayout<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(
                    LinearGradient(colors: [tint.opacity(0.8), tint], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .shadow(color: tint.opacity(0.35), radius: 14, y: 6)
            VStack(spacing: 8) {
                Text(title).font(.title.weight(.bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
    }
}

struct PermissionRow: View {
    let symbol: String
    let title: String
    let status: PermissionStatus
    let actionTitle: String
    let action: () -> Void

    private static let badges: [PermissionStatus: (symbol: String, color: Color, key: String)] = [
        .granted: ("checkmark.circle.fill", .green, "onboarding.status.granted"),
        .denied: ("xmark.circle.fill", .red, "onboarding.status.denied"),
        .unknown: ("circle.dashed", .secondary, "onboarding.status.unknown")
    ]

    var body: some View {
        let badge = Self.badges[status] ?? ("circle", .secondary, "")
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(title).fontWeight(.medium)
            Spacer()
            Label(L(badge.key), systemImage: badge.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(badge.color)
            if status != .granted {
                Button(actionTitle, action: action).controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct WelcomeStep: View {
    private let features: [(String, String)] = [
        ("checkmark.seal.fill", "onboarding.welcome.safe"),
        ("key.fill", "onboarding.welcome.secrets"),
        ("sparkles", "onboarding.welcome.clean"),
        ("icloud.and.arrow.up.fill", "onboarding.welcome.migrate")
    ]

    var body: some View {
        StepLayout(symbol: "arrow.triangle.branch", tint: .orange, title: L("onboarding.welcome.title"), message: L("onboarding.welcome.message")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.1) { feature in
                    Label(L(feature.1), systemImage: feature.0)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
        }
    }
}

struct FullDiskStep: View {
    @State private var granted = PermissionService.hasFullDiskAccess

    var body: some View {
        StepLayout(symbol: "lock.open.fill", tint: .blue, title: L("onboarding.fullDisk.title"), message: L("onboarding.fullDisk.message")) {
            PermissionRow(
                symbol: "internaldrive",
                title: L("onboarding.fullDisk.row"),
                status: granted ? .granted : .unknown,
                actionTitle: L("onboarding.openSettings"),
                action: PermissionService.openFullDiskSettings
            )
            Text(L("onboarding.fullDisk.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = PermissionService.hasFullDiskAccess
        }
    }
}

struct FoldersStep: View {
    @State private var statuses: [ProtectedFolder: PermissionStatus] = [:]

    var body: some View {
        StepLayout(symbol: "folder.fill.badge.person.crop", tint: .teal, title: L("onboarding.folders.title"), message: L("onboarding.folders.message")) {
            VStack(spacing: 8) {
                ForEach(ProtectedFolder.allCases) { folder in
                    PermissionRow(
                        symbol: folder.symbol,
                        title: L(folder.titleKey),
                        status: statuses[folder] ?? .unknown,
                        actionTitle: L(statuses[folder] == .denied ? "onboarding.openSettings" : "onboarding.allow")
                    ) { Task { await request(folder) } }
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func request(_ folder: ProtectedFolder) async {
        guard statuses[folder] != .denied else {
            PermissionService.openFilesSettings()
            return
        }
        statuses[folder] = await PermissionService.request(folder)
    }

    private func refresh() {
        statuses = Dictionary(uniqueKeysWithValues: ProtectedFolder.allCases.map { ($0, PermissionService.status(of: $0)) })
    }
}

struct GitStep: View {
    @State private var version: String?
    @State private var checked = false

    var body: some View {
        StepLayout(symbol: "terminal.fill", tint: .gray, title: L("onboarding.git.title"), message: L("onboarding.git.message")) {
            PermissionRow(
                symbol: "chevron.left.forwardslash.chevron.right",
                title: version ?? L("onboarding.git.missing"),
                status: checked ? (version == nil ? .denied : .granted) : .unknown,
                actionTitle: L("onboarding.git.install")
            ) { Task { await PermissionService.installCommandLineTools() } }
            Text(L("onboarding.git.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .task { await check() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await check() }
        }
    }

    private func check() async {
        version = await PermissionService.gitVersion()
        checked = true
    }
}

struct BackupStep: View {
    @Environment(RepositoryStore.self) private var store

    var body: some View {
        StepLayout(symbol: "externaldrive.fill.badge.icloud", tint: .purple, title: L("onboarding.backup.title"), message: L("onboarding.backup.message")) {
            PermissionRow(
                symbol: "folder",
                title: store.settings.backupFolder.map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") } ?? L("settings.backupFolder.none"),
                status: store.settings.backupFolder == nil ? .unknown : .granted,
                actionTitle: L("action.choose")
            ) { _ = store.chooseBackupFolder() }
            Text(L("onboarding.backup.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

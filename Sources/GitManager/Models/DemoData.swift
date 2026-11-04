import Foundation

enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.environment["GITMANAGER_DEMO"] == "1" }
    static var selectedName: String? { ProcessInfo.processInfo.environment["GITMANAGER_DEMO_SELECT"] }

    private static let gigabyte: Int64 = 1_073_741_824
    private static let megabyte: Int64 = 1_048_576

    static let repositories: [Repository] = [
        make("aurora-web", size: 4 * gigabyte, clean: [("node_modules/", 3 * gigabyte), (".next/", 420 * megabyte)], secrets: [".env", ".env.local"], changes: 3, unpushed: 2, days: 1),
        make("pixel-forge", size: 9 * gigabyte, clean: [("Library/", 6 * gigabyte), ("Temp/", 900 * megabyte)], secrets: [], days: 12),
        make("atlas-api", size: 1_800 * megabyte, clean: [("node_modules/", 1_400 * megabyte), ("dist/", 60 * megabyte)], secrets: [".env", "certs/server.pem"], backedUp: true, days: 4),
        make("orbit-ios", size: 2_600 * megabyte, clean: [("Pods/", 1_900 * megabyte)], secrets: ["GoogleService-Info.plist"], backedUp: true, days: 30),
        make("notes-cli", size: 48 * megabyte, clean: [("target/", 40 * megabyte)], secrets: [], remote: false, days: 90),
        make("design-tokens", size: 320 * megabyte, clean: [("node_modules/", 300 * megabyte)], secrets: [], stashes: 1, days: 7),
        make("ml-playground", size: 5 * gigabyte, clean: [(".venv/", 3 * gigabyte), ("__pycache__/", 12 * megabyte)], secrets: [".env"], backedUp: true, days: 60),
        make("landing-2024", size: 780 * megabyte, clean: [("node_modules/", 760 * megabyte)], secrets: [], days: 300),
        make("dotfiles", size: 6 * megabyte, clean: [], secrets: [], days: 2),
        make("side-quest", size: 210 * megabyte, clean: [("build/", 150 * megabyte)], secrets: [".env"], remote: false, days: 45)
    ]

    private static func make(
        _ name: String,
        size: Int64,
        clean: [(String, Int64)],
        secrets: [String],
        backedUp: Bool = false,
        remote: Bool = true,
        changes: Int = 0,
        unpushed: Int = 0,
        stashes: Int = 0,
        days: Double
    ) -> Repository {
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/Developer/" + name)
        let remotes = remote ? [GitRemote(name: "origin", url: "git@github.com:octodev/\(name).git")] : []
        let files = secrets.map { SensitiveFile(relativePath: $0, size: 512, modified: .now.addingTimeInterval(-86_400 * 3), sha256: $0) }
        let snapshot = GitSnapshot(
            branch: "main",
            remotes: remotes,
            changes: changes,
            unpushed: unpushed,
            stashes: stashes,
            hasCommits: true,
            lastCommit: .now.addingTimeInterval(-86_400 * days)
        )
        return Repository(
            url: url,
            snapshot: snapshot,
            size: size,
            cleanables: clean.map { CleanableItem(relativePath: $0.0, size: $0.1) },
            sensitiveFiles: files,
            ledgerHashes: backedUp ? Dictionary(uniqueKeysWithValues: secrets.map { ($0, $0) }) : [:]
        )
    }
}

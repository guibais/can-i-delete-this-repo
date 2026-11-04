import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var roots: [String] = [NSHomeDirectory()]
    var excluded: [String] = AppSettings.defaultExclusions
    var maxDepth = 7
    var backupFolder: String?
    var vaultRemote: String?

    static let defaultExclusions = [
        "Library", "Applications", "Pictures", "Music", "Movies", "Public",
        "node_modules", "Pods", "DerivedData", "vendor", "venv", "Parallels", "OrbStack"
    ]

    private static let storageKey = "app.settings"

    var rootURLs: [URL] { roots.map { URL(fileURLWithPath: $0, isDirectory: true) } }
    var backupURL: URL? { backupFolder.map { URL(fileURLWithPath: $0, isDirectory: true) } }

    static func load() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct BackupLedger: Codable, Sendable {
    private var entries: [String: [String: String]] = [:]

    private static let storageKey = "app.backupLedger.v2"

    func hashes(for path: String) -> [String: String] { entries[path] ?? [:] }

    mutating func mark(_ repositories: [Repository]) {
        repositories.forEach { repository in
            entries[repository.id] = Dictionary(
                repository.sensitiveFiles.map { ($0.relativePath, $0.sha256) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        save()
    }

    static func load() -> BackupLedger {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let ledger = try? JSONDecoder().decode(BackupLedger.self, from: data)
        else { return BackupLedger() }
        return ledger
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

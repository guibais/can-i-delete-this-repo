import Foundation

struct CleanableItem: Hashable, Sendable, Identifiable {
    let relativePath: String
    let size: Int64

    var id: String { relativePath }
}

struct SensitiveFile: Hashable, Sendable, Identifiable {
    let relativePath: String
    let size: Int64
    let modified: Date
    let sha256: String

    var id: String { relativePath }
}

struct Repository: Identifiable, Hashable, Sendable {
    let url: URL
    var snapshot: GitSnapshot
    var size: Int64
    var cleanables: [CleanableItem]
    var sensitiveFiles: [SensitiveFile]
    var ledgerHashes: [String: String] = [:]
    var vaultFiles: [String: VaultEntry] = [:]

    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var displayPath: String { url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
    var cleanableSize: Int64 { cleanables.reduce(0) { $0 + $1.size } }
    var hasRemote: Bool { !snapshot.remotes.isEmpty }
    var severityRank: Int { severity.rawValue }
    var lastCommitSort: Date { snapshot.lastCommit ?? .distantPast }

    var hasSecrets: Bool { !sensitiveFiles.isEmpty || !vaultFiles.isEmpty }

    var secretItems: [SecretItem] {
        let localPaths = Set(sensitiveFiles.map(\.relativePath))
        let local = sensitiveFiles.map {
            SecretItem(relativePath: $0.relativePath, state: state(of: $0), encrypted: vaultFiles[$0.relativePath]?.encrypted)
        }
        let missing = vaultFiles.keys
            .filter { !localPaths.contains($0) }
            .sorted()
            .map { SecretItem(relativePath: $0, state: .missingLocally, encrypted: vaultFiles[$0]?.encrypted) }
        return local + missing
    }

    var pendingSecrets: [SecretItem] {
        secretItems.filter { $0.state.needsBackup }
    }

    var restorableSecrets: [SecretItem] {
        secretItems.filter { $0.state.canRestore }
    }

    private func state(of file: SensitiveFile) -> SecretSyncState {
        guard let entry = vaultFiles[file.relativePath] else {
            return ledgerHashes[file.relativePath] == file.sha256 ? .synced : .notBackedUp
        }
        if entry.sha256 == file.sha256 { return .synced }
        return file.modified > entry.updatedAt ? .localNewer : .vaultNewer
    }

    var issues: [RepoIssue] {
        let counts: [(IssueKind, Int)] = [
            (.noRemote, hasRemote ? 0 : 1),
            (.noCommits, snapshot.hasCommits ? 0 : 1),
            (.uncommittedChanges, snapshot.changes),
            (.unpushedCommits, snapshot.unpushed),
            (.stashes, snapshot.stashes),
            (.secretsNotBackedUp, pendingSecrets.count),
            (.behindRemote, snapshot.behind)
        ]
        return counts.filter { $0.1 > 0 }.map { RepoIssue(kind: $0.0, count: $0.1) }
    }

    var severity: Severity {
        issues.map(\.kind.severity).max() ?? .safe
    }

    var isSafeToDelete: Bool { severity == .safe }
}

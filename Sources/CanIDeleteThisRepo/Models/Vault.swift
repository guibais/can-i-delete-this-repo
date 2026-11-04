import Foundation

struct VaultEntry: Codable, Hashable, Sendable {
    let sha256: String
    let size: Int64
    let updatedAt: Date
    let machine: String
}

struct VaultManifest: Codable, Sendable {
    var identity: String
    var name: String
    var remote: String?
    var files: [String: VaultEntry]
}

struct VaultIndexEntry: Codable, Hashable, Sendable, Identifiable {
    let identity: String
    let name: String
    let remote: String?
    let updatedAt: Date
    let fileCount: Int

    var id: String { identity }
}

struct VaultIndex: Codable, Sendable {
    var projects: [String: VaultIndexEntry] = [:]
}

struct VaultConfig: Codable, Sendable {
    let version: Int
    let keyCheck: String
}

struct VaultBackupSummary: Sendable {
    let projects: [String]
    let files: Int
}

enum RepoVisibility: Sendable {
    case privateRepo
    case publicRepo
    case unknown
}

enum VaultConnection: Sendable, Equatable {
    case needsNewKey
    case needsRecoveryKey
    case ready
    case failed(String)
}

enum SecretSyncState: String, Hashable, Sendable {
    case synced
    case notBackedUp
    case localNewer
    case vaultNewer
    case missingLocally

    var needsBackup: Bool { self == .notBackedUp || self == .localNewer }
    var canRestore: Bool { self == .vaultNewer || self == .missingLocally }
}

struct SecretItem: Identifiable, Hashable, Sendable {
    let relativePath: String
    let state: SecretSyncState

    var id: String { relativePath }
}

struct VaultError: LocalizedError {
    let messageKey: String

    var errorDescription: String? { L(messageKey) }

    static let missingKey = VaultError(messageKey: "vault.error.missingKey")
    static let wrongKey = VaultError(messageKey: "vault.error.wrongKey")
    static let invalidData = VaultError(messageKey: "vault.error.invalidData")
}

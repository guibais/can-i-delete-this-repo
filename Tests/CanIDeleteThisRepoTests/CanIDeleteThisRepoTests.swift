import XCTest
@testable import CanIDeleteThisRepo

final class GitParsingTests: XCTestCase {
    func testParseBranchWithUpstream() {
        XCTAssertEqual(GitService.parseBranch("## main...origin/main [ahead 2, behind 3]"), "main")
    }

    func testParseBranchWithoutCommits() {
        XCTAssertEqual(GitService.parseBranch("## No commits yet on develop"), "develop")
    }

    func testParseBranchDetached() {
        XCTAssertNil(GitService.parseBranch("## HEAD (no branch)"))
    }

    func testParseBehind() {
        XCTAssertEqual(GitService.parseBehind("## main...origin/main [ahead 2, behind 13]"), 13)
        XCTAssertEqual(GitService.parseBehind("## main...origin/main"), 0)
    }

    func testParseRemotes() {
        let output = """
        origin\tgit@github.com:me/app.git (fetch)
        origin\tgit@github.com:me/app.git (push)
        backup\thttps://gitlab.com/me/app.git (fetch)
        """
        let remotes = GitService.parseRemotes(output)
        XCTAssertEqual(remotes.map(\.name), ["origin", "backup"])
    }

    func testRemoteWebURL() {
        XCTAssertEqual(GitRemote(name: "o", url: "git@github.com:me/app.git").webURL?.absoluteString, "https://github.com/me/app")
        XCTAssertEqual(GitRemote(name: "o", url: "https://gitlab.com/me/app.git").webURL?.absoluteString, "https://gitlab.com/me/app")
    }
}

final class FilePatternTests: XCTestCase {
    func testCleanable() {
        XCTAssertTrue(FilePatterns.isCleanable("node_modules/"))
        XCTAssertTrue(FilePatterns.isCleanable("packages/web/.next/"))
        XCTAssertFalse(FilePatterns.isCleanable("src/"))
        XCTAssertFalse(FilePatterns.isCleanable("node_modules"))
    }

    func testSensitive() {
        XCTAssertTrue(FilePatterns.isSensitive(".env"))
        XCTAssertTrue(FilePatterns.isSensitive("apps/api/.env.local"))
        XCTAssertTrue(FilePatterns.isSensitive("certs/server.pem"))
        XCTAssertTrue(FilePatterns.isSensitive("ios/GoogleService-Info.plist"))
        XCTAssertFalse(FilePatterns.isSensitive("dist/index.js"))
        XCTAssertFalse(FilePatterns.isSensitive(".env/"))
    }
}

final class RepositoryTests: XCTestCase {
    private func repository(_ snapshot: GitSnapshot, secrets: [SensitiveFile] = [], ledger: [String: String] = [:], vault: [String: VaultEntry] = [:]) -> Repository {
        Repository(url: URL(fileURLWithPath: "/tmp/demo"), snapshot: snapshot, size: 0, cleanables: [], sensitiveFiles: secrets, ledgerHashes: ledger, vaultFiles: vault)
    }

    private let synced = GitSnapshot(branch: "main", remotes: [GitRemote(name: "origin", url: "git@github.com:me/a.git")], hasCommits: true)

    func testSyncedRepositoryIsSafe() {
        XCTAssertTrue(repository(synced).isSafeToDelete)
    }

    func testLocalOnlyIsDanger() {
        var snapshot = synced
        snapshot.remotes = []
        XCTAssertEqual(repository(snapshot).severity, .danger)
    }

    func testUnpushedNeedsAttention() {
        var snapshot = synced
        snapshot.unpushed = 2
        XCTAssertEqual(repository(snapshot).severity, .warning)
    }

    func testSecretsRequireBackup() {
        let secret = SensitiveFile(relativePath: ".env", size: 10, modified: Date(timeIntervalSince1970: 100), sha256: "abc")
        XCTAssertEqual(repository(synced, secrets: [secret]).severity, .warning)
        XCTAssertTrue(repository(synced, secrets: [secret], ledger: [".env": "abc"]).isSafeToDelete)
    }

    func testVaultStates() {
        let secret = SensitiveFile(relativePath: ".env", size: 10, modified: Date(timeIntervalSince1970: 100), sha256: "abc")
        let newer = VaultEntry(sha256: "zzz", size: 10, updatedAt: Date(timeIntervalSince1970: 500), machine: "m")
        let only = VaultEntry(sha256: "x", size: 1, updatedAt: .now, machine: "m")
        let repo = repository(synced, secrets: [secret], vault: [".env": newer, "api/.env": only])
        XCTAssertEqual(repo.secretItems.map(\.state), [.vaultNewer, .missingLocally])
        XCTAssertTrue(repo.isSafeToDelete)
        XCTAssertEqual(repo.restorableSecrets.count, 2)
    }
}

final class VaultCryptoTests: XCTestCase {
    func testRoundTrip() throws {
        let key = VaultCrypto.generateKey()
        let data = Data("API_KEY=123".utf8)
        let encrypted = try VaultCrypto.encrypt(data, with: key)
        XCTAssertNotEqual(encrypted, data)
        XCTAssertEqual(try VaultCrypto.decrypt(encrypted, with: key), data)
    }

    func testRecoveryKeyRoundTrip() throws {
        let key = VaultCrypto.generateKey()
        let recovered = try XCTUnwrap(VaultCrypto.key(fromRecovery: VaultCrypto.recoveryKey(for: key).lowercased()))
        let encrypted = try VaultCrypto.encrypt(Data("x".utf8), with: key)
        XCTAssertEqual(try VaultCrypto.decrypt(encrypted, with: recovered), Data("x".utf8))
    }

    func testIdentityUsesRemote() {
        let remotes = [GitRemote(name: "origin", url: "git@github.com:Me/App.git")]
        XCTAssertEqual(VaultService.identity(for: URL(fileURLWithPath: "/x"), remotes: remotes), "github.com/me/app")
    }

    func testRestoreScriptQuotesPaths() {
        let snapshot = GitSnapshot(remotes: [GitRemote(name: "origin", url: "git@github.com:me/a.git")], hasCommits: true)
        let repo = Repository(url: URL(fileURLWithPath: "/tmp/demo"), snapshot: snapshot, size: 0, cleanables: [], sensitiveFiles: [])
        let script = BackupService.restoreScript(for: [repo])
        XCTAssertTrue(script.contains("restore 'git@github.com:me/a.git'"))
    }
}

final class OverhaulTests: XCTestCase {
    func testParseAheadAndBehind() {
        let header = "## main...origin/main [ahead 3, behind 2]"
        XCTAssertEqual(GitService.parseAhead(header), 3)
        XCTAssertEqual(GitService.parseBehind(header), 2)
        XCTAssertEqual(GitService.parseAhead("## main...origin/main"), 0)
    }

    func testLegacyVaultEntryDefaultsToEncrypted() throws {
        let json = Data(#"{"sha256":"a","size":1,"updatedAt":"2026-01-01T00:00:00Z","machine":"Mac"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertTrue(try decoder.decode(VaultEntry.self, from: json).encrypted)
    }

    func testActivityProgressUsesFreedBytesWhenGoalIsSet() {
        var activity = Activity(title: "", symbol: "", total: 4, completed: 1, goal: 200, freed: 50)
        XCTAssertEqual(activity.progress, 0.25)
        XCTAssertEqual(activity.counter, "1/4")
        activity.goal = nil
        XCTAssertEqual(activity.progress, 0.25)
        activity.outcome = .success("ok")
        XCTAssertEqual(activity.progress, 1)
    }

    func testSavingsLedgerAccumulates() {
        var ledger = SavingsLedger()
        ledger.add(100)
        ledger.add(-5)
        XCTAssertEqual(ledger.totalFreed, 100)
    }

    func testRemoveProgressivelyDeletesEverything() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("a/b"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("c.txt"))
        var fractions: [Double] = []
        for try await fraction in FileOperations.removeProgressively(folder) {
            fractions.append(fraction)
        }
        XCTAssertEqual(fractions.last, 1)
        XCTAssertEqual(fractions, fractions.sorted())
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }
}

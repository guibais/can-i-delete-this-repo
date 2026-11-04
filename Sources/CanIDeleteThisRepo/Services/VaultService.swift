import CryptoKit
import Foundation

enum VaultService {
    static let root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("CanIDeleteThisRepo/vault", isDirectory: true)

    private static let configURL = root.appendingPathComponent(".vault.json")
    private static let indexURL = root.appendingPathComponent("index.json")
    private static let checkPhrase = Data("can-i-delete-this-repo-vault".utf8)
    private static let machine = Host.current().localizedName ?? "Mac"

    static var isCloned: Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path)
    }

    static var config: VaultConfig? {
        read(VaultConfig.self, at: configURL)
    }

    static var isInitialized: Bool { config != nil }
    static var hasKeyCheck: Bool { config?.keyCheck != nil }

    static func identity(for url: URL, remotes: [GitRemote]) -> String {
        let remote = remotes.first(where: { $0.name == "origin" }) ?? remotes.first
        guard let web = remote?.webURL, let host = web.host else {
            return "local/" + BackupService.relativeHomePath(url)
        }
        return (host + web.path).lowercased()
    }

    static func manifest(for identity: String) -> VaultManifest? {
        read(VaultManifest.self, at: manifestURL(for: identity))
    }

    static func index() -> VaultIndex {
        read(VaultIndex.self, at: indexURL) ?? VaultIndex()
    }

    static func verify(_ key: SymmetricKey) -> Bool {
        guard
            let check = config?.keyCheck,
            let data = Data(base64Encoded: check),
            let plain = try? VaultCrypto.decrypt(data, with: key)
        else { return false }
        return plain == checkPhrase
    }

    static func initialize(with key: SymmetricKey?) throws {
        let check = try key.map { try VaultCrypto.encrypt(checkPhrase, with: $0).base64EncodedString() }
        try write(VaultConfig(version: 1, keyCheck: check), to: configURL)
        try readme.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    }

    static func connect(remote: String) async -> CommandResult {
        guard isCloned else {
            try? FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: root)
            return await GitService.git(["clone", remote, root.path], at: root.deletingLastPathComponent())
        }
        return await git(["remote", "set-url", "origin", remote])
    }

    static func disconnect() {
        try? FileManager.default.removeItem(at: root)
    }

    static func createRepository(named name: String) async -> (CommandResult, String?) {
        let create = await Shell.run("/usr/bin/env", ["gh", "repo", "create", name, "--private"])
        guard create.succeeded else { return (create, nil) }
        let view = await Shell.run("/usr/bin/env", ["gh", "repo", "view", name, "--json", "url", "-q", ".url"])
        return (view, view.succeeded ? view.trimmedOutput + ".git" : nil)
    }

    static func visibility(of remote: String) async -> RepoVisibility {
        guard let web = GitRemote(name: "origin", url: remote).webURL, web.host == "github.com",
              let api = URL(string: "https://api.github.com/repos" + web.path),
              let (data, response) = try? await URLSession.shared.data(from: api),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .unknown }
        if status == 404 { return .privateRepo }
        let isPrivate = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["private"] as? Bool
        return isPrivate == false ? .publicRepo : .privateRepo
    }

    static func pull() async -> CommandResult {
        let upstream = await git(["rev-parse", "--abbrev-ref", "@{u}"])
        guard upstream.succeeded else { return .success }
        return await git(["pull", "--rebase", "--autostash"])
    }

    static func commit(message: String) async -> CommandResult {
        _ = await git(["add", "--all", "--force", "--", ".", ":(exclude,glob)**/.DS_Store"])
        let unchanged = await git(["diff", "--cached", "--quiet"])
        guard !unchanged.succeeded else { return .success }
        let email = await git(["config", "user.email"])
        let identity = email.trimmedOutput.isEmpty
            ? ["-c", "user.name=Can I Delete This Repo", "-c", "user.email=can-i-delete-this-repo@localhost"]
            : []
        return await git(identity + ["commit", "-m", message])
    }

    static func push() async -> CommandResult {
        await git(["push", "-u", "origin", "HEAD"])
    }

    static func gitInfo() async -> VaultGitInfo {
        async let branch = git(["rev-parse", "--abbrev-ref", "HEAD"])
        async let last = git(["log", "-1", "--format=%s%x1f%ct"])
        async let count = git(["rev-list", "--count", "HEAD"])
        async let status = git(["status", "--porcelain=v1", "-b"])

        let lastParts = (await last).trimmedOutput.components(separatedBy: "\u{1f}")
        let statusLines = (await status).output.split(separator: "\n").map(String.init)
        let header = statusLines.first ?? ""
        let branchName = (await branch).trimmedOutput

        return VaultGitInfo(
            branch: branchName.isEmpty || branchName == "HEAD" ? GitService.parseBranch(header) : branchName,
            lastCommitMessage: lastParts.first.flatMap { $0.isEmpty ? nil : $0 },
            lastCommitDate: lastParts.dropFirst().first.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:)),
            commits: Int((await count).trimmedOutput) ?? 0,
            ahead: GitService.parseAhead(header),
            behind: GitService.parseBehind(header),
            pendingChanges: max(statusLines.count - 1, 0)
        )
    }

    static func backupRepository(_ repository: Repository, key: SymmetricKey?, encrypt: Bool) throws -> Int {
        guard !repository.sensitiveFiles.isEmpty else { return 0 }
        guard !encrypt || key != nil else { throw VaultError.missingKey }

        let identity = identity(for: repository.url, remotes: repository.snapshot.remotes)
        var manifest = manifest(for: identity) ?? VaultManifest(
            identity: identity,
            name: repository.name,
            remote: repository.snapshot.remotes.first?.url,
            files: [:]
        )
        let changed = repository.sensitiveFiles.filter { file in
            guard let entry = manifest.files[file.relativePath] else { return true }
            return entry.sha256 != file.sha256 || entry.encrypted != encrypt
        }
        guard !changed.isEmpty else { return 0 }

        for file in changed {
            let plain = try Data(contentsOf: repository.url.appendingPathComponent(file.relativePath))
            let destination = storedURL(identity: identity, path: file.relativePath, encrypted: encrypt)
            try? FileManager.default.removeItem(at: storedURL(identity: identity, path: file.relativePath, encrypted: !encrypt))
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encode(plain, with: encrypt ? key : nil).write(to: destination, options: .atomic)
            manifest.files[file.relativePath] = VaultEntry(
                sha256: file.sha256,
                size: file.size,
                updatedAt: .now,
                machine: machine,
                encrypted: encrypt
            )
        }

        manifest.remote = repository.snapshot.remotes.first?.url ?? manifest.remote
        try write(manifest, to: manifestURL(for: identity))

        var index = index()
        index.projects[identity] = VaultIndexEntry(
            identity: identity,
            name: repository.name,
            remote: manifest.remote,
            updatedAt: .now,
            fileCount: manifest.files.count
        )
        try write(index, to: indexURL)
        return changed.count
    }

    static func restore(_ repository: Repository, key: SymmetricKey?) throws -> Int {
        let identity = identity(for: repository.url, remotes: repository.snapshot.remotes)
        let items = repository.restorableSecrets.compactMap { item in
            repository.vaultFiles[item.relativePath].map { (item.relativePath, $0) }
        }
        for (path, entry) in items {
            let stored = try Data(contentsOf: storedURL(identity: identity, path: path, encrypted: entry.encrypted))
            let plain = try decode(stored, encrypted: entry.encrypted, key: key)
            let destination = repository.url.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try keepCopy(of: destination)
            try plain.write(to: destination, options: .atomic)
        }
        return items.count
    }

    private static func encode(_ data: Data, with key: SymmetricKey?) throws -> Data {
        guard let key else { return data }
        return try VaultCrypto.encrypt(data, with: key)
    }

    private static func decode(_ data: Data, encrypted: Bool, key: SymmetricKey?) throws -> Data {
        guard encrypted else { return data }
        guard let key else { throw VaultError.missingKey }
        return try VaultCrypto.decrypt(data, with: key)
    }

    private static func keepCopy(of url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.copyItem(at: url, to: backup)
    }

    private static func git(_ arguments: [String]) async -> CommandResult {
        await GitService.git(arguments, at: root)
    }

    private static func manifestURL(for identity: String) -> URL {
        root.appendingPathComponent(identity, isDirectory: true).appendingPathComponent("manifest.json")
    }

    private static func storedURL(identity: String, path: String, encrypted: Bool) -> URL {
        root.appendingPathComponent(identity, isDirectory: true)
            .appendingPathComponent("files/" + path + (encrypted ? ".enc" : ""))
    }

    private static func read<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static let readme = """
    # Can I Delete This Repo? · Vault

    Backup of ignored secrets (.env and friends) managed by Can I Delete This Repo? (github.com/guibais/can-i-delete-this-repo).

    - Encrypted files end with `.enc`: the 4 bytes `CDR1` followed by the CryptoKit AES.GCM combined box (nonce + ciphertext + tag).
    - Files without `.enc` were backed up in plain text by choice.
    - The encryption key lives in your Keychain. Keep the recovery key in a password manager.
    - Layout: `<host>/<owner>/<repo>/manifest.json` and `<host>/<owner>/<repo>/files/<path>[.enc]`.

    Never make this repository public.
    """
}

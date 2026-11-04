import Foundation

struct BackupManifest: Codable {
    struct Entry: Codable {
        let name: String
        let path: String
        let branch: String?
        let remotes: [String: String]
        let secrets: [String]
    }

    let createdAt: Date
    let host: String
    let repositories: [Entry]
}

enum BackupService {
    static func prepare(in folder: URL) throws -> URL {
        let root = folder.appendingPathComponent("CanIDeleteThisRepo-Backup-\(timestamp())", isDirectory: true)
        try FileManager.default.createDirectory(at: files(in: root), withIntermediateDirectories: true)
        return root
    }

    static func copySecrets(of repository: Repository, to root: URL) throws {
        let fileManager = FileManager.default
        let base = files(in: root).appendingPathComponent(relativeHomePath(repository.url), isDirectory: true)
        try repository.sensitiveFiles.forEach { file in
            let source = repository.url.appendingPathComponent(file.relativePath)
            let destination = base.appendingPathComponent(file.relativePath)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    static func finalize(_ repositories: [Repository], at root: URL) throws {
        try manifest(for: repositories).write(to: root.appendingPathComponent("manifest.json"))
        let script = root.appendingPathComponent("restore.sh")
        try restoreScript(for: repositories).write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    }

    static func relativeHomePath(_ url: URL) -> String {
        let home = NSHomeDirectory() + "/"
        let path = url.path
        return path.hasPrefix(home) ? String(path.dropFirst(home.count)) : String(path.drop(while: { $0 == "/" }))
    }

    static func restoreScript(for repositories: [Repository]) -> String {
        let header = """
        #!/bin/bash
        set -uo pipefail
        BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)/files"

        restore() {
          local url="$1"
          local target="$HOME/$2"
          if [ ! -e "$target/.git" ]; then
            mkdir -p "$(dirname "$target")"
            git clone "$url" "$target" || echo "Failed to clone $url"
          fi
          if [ -d "$BACKUP_DIR/$2" ]; then
            cp -R "$BACKUP_DIR/$2/." "$target/"
          fi
        }

        """
        let lines = repositories.map(restoreLine)
        return header + lines.joined(separator: "\n") + "\n"
    }

    private static func restoreLine(for repository: Repository) -> String {
        let path = quote(relativeHomePath(repository.url))
        guard let remote = repository.snapshot.remotes.first(where: { $0.name == "origin" }) ?? repository.snapshot.remotes.first
        else { return "echo \(quote("Local only, not restorable: " + repository.displayPath))" }
        return "restore \(quote(remote.url)) \(path)"
    }

    private static func files(in root: URL) -> URL {
        root.appendingPathComponent("files", isDirectory: true)
    }

    private static func manifest(for repositories: [Repository]) throws -> Data {
        let entries = repositories.map { repository in
            BackupManifest.Entry(
                name: repository.name,
                path: repository.url.path,
                branch: repository.snapshot.branch,
                remotes: Dictionary(uniqueKeysWithValues: repository.snapshot.remotes.map { ($0.name, $0.url) }),
                secrets: repository.sensitiveFiles.map(\.relativePath)
            )
        }
        let manifest = BackupManifest(createdAt: .now, host: Host.current().localizedName ?? "Mac", repositories: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(manifest)
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: .now)
    }
}

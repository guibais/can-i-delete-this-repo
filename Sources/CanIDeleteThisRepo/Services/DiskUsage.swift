import Foundation

enum DiskUsage {
    static func size(of url: URL) async -> Int64 {
        await sizes(of: [url.path]).values.first ?? 0
    }

    static func cleanables(in url: URL, ignored: [String]) async -> [CleanableItem] {
        let entries = ignored.filter(FilePatterns.isCleanable)
        guard !entries.isEmpty else { return [] }
        let paths = entries.map { url.appendingPathComponent($0).path }
        let measured = await sizes(of: paths)
        return zip(entries, paths)
            .map { CleanableItem(relativePath: $0.0, size: measured[normalize($0.1)] ?? 0) }
            .sorted { $0.size > $1.size }
    }

    static func sensitiveFiles(in url: URL, ignored: [String]) -> [SensitiveFile] {
        ignored.filter(FilePatterns.isSensitive).compactMap { entry in
            let fileURL = url.appendingPathComponent(entry)
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true
            else { return nil }
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return SensitiveFile(
                relativePath: entry,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate ?? .distantPast,
                sha256: VaultCrypto.sha256(data)
            )
        }
    }

    private static func sizes(of paths: [String]) async -> [String: Int64] {
        let result = await Shell.run("/usr/bin/du", ["-sk"] + paths)
        return result.output
            .split(separator: "\n")
            .reduce(into: [String: Int64]()) { partial, line in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2, let kilobytes = Int64(parts[0]) else { return }
                partial[normalize(String(parts[1]))] = kilobytes * 1024
            }
    }

    private static func normalize(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

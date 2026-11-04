import Foundation

enum RepositoryScanner {
    private static let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]

    static func find(in roots: [URL], excluding excluded: Set<String>, maxDepth: Int) -> [URL] {
        var found: [URL] = []
        roots.forEach { walk($0, depth: 0, maxDepth: maxDepth, excluded: excluded, found: &found) }
        return Array(Set(found)).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func walk(_ url: URL, depth: Int, maxDepth: Int, excluded: Set<String>, found: inout [URL]) {
        guard depth <= maxDepth,
              let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(resourceKeys))
        else { return }

        if items.contains(where: { $0.lastPathComponent == ".git" }) {
            found.append(url.standardizedFileURL)
            return
        }

        items
            .filter { isTraversable($0, excluded: excluded) }
            .forEach { walk($0, depth: depth + 1, maxDepth: maxDepth, excluded: excluded, found: &found) }
    }

    private static func isTraversable(_ url: URL, excluded: Set<String>) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), !excluded.contains(name),
              let values = try? url.resourceValues(forKeys: resourceKeys)
        else { return false }
        return values.isDirectory == true && values.isPackage != true && values.isSymbolicLink != true
    }
}

enum RepositoryInspector {
    static func inspect(_ url: URL, ledgerHashes: [String: String]) async -> Repository {
        async let snapshot = GitService.snapshot(at: url)
        async let size = DiskUsage.size(of: url)
        let gitSnapshot = await snapshot
        let cleanables = await DiskUsage.cleanables(in: url, ignored: gitSnapshot.ignored)
        return Repository(
            url: url,
            snapshot: gitSnapshot,
            size: await size,
            cleanables: cleanables,
            sensitiveFiles: DiskUsage.sensitiveFiles(in: url, ignored: gitSnapshot.ignored),
            ledgerHashes: ledgerHashes,
            vaultFiles: VaultService.manifest(for: VaultService.identity(for: url, remotes: gitSnapshot.remotes))?.files ?? [:]
        )
    }
}

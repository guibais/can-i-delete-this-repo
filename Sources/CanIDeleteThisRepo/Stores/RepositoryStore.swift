import Foundation
import Observation

@Observable
@MainActor
final class RepositoryStore {
    var repositories: [Repository] = []
    var isScanning = false
    var scanProgress: Double = 0
    var busyIDs: Set<Repository.ID> = []
    var toast: Toast?
    var settings: AppSettings { didSet { settings.save() } }
    var isVaultBusy = false
    var hasVaultKey = VaultCrypto.loadKey() != nil

    var ledger = BackupLedger.load()
    private let concurrency = 6

    init() {
        settings = AppSettings.load()
        guard DemoData.isEnabled else { return }
        repositories = DemoData.repositories
    }

    var totalSize: Int64 { repositories.reduce(0) { $0 + $1.size } }
    var totalCleanable: Int64 { repositories.reduce(0) { $0 + $1.cleanableSize } }

    func count(_ filter: SidebarFilter) -> Int {
        repositories.filter(filter.matches).count
    }

    func repositories(for ids: Set<Repository.ID>) -> [Repository] {
        repositories.filter { ids.contains($0.id) }
    }

    func scan() async {
        guard !isScanning, !DemoData.isEnabled else { return }
        isScanning = true
        scanProgress = 0
        defer { isScanning = false }

        let roots = settings.rootURLs
        let excluded = Set(settings.excluded)
        let depth = settings.maxDepth
        let urls = await Task.detached(priority: .userInitiated) {
            RepositoryScanner.find(in: roots, excluding: excluded, maxDepth: depth)
        }.value

        let found = Set(urls.map(\.path))
        repositories.removeAll { !found.contains($0.id) }
        await inspect(urls)
    }

    func refresh(_ repository: Repository) async {
        await inspect([repository.url])
    }

    func fetchAll() async {
        let targets = repositories.filter(\.hasRemote)
        await forEachConcurrently(targets) { await GitService.fetch(at: $0.url) } onResult: { _ in }
        await inspect(targets.map(\.url))
        toast = .success(L("toast.fetchedAll"))
    }

    func fetch(_ repository: Repository) async {
        await perform(on: repository, success: "toast.fetched") { await GitService.fetch(at: repository.url) }
    }

    func push(_ repository: Repository) async {
        await perform(on: repository, success: "toast.pushed") { await GitService.push(at: repository.url) }
    }

    func pushAll(_ repository: Repository) async {
        await perform(on: repository, success: "toast.pushed") { await GitService.pushAll(at: repository.url) }
    }

    func commitAndPush(_ repository: Repository, message: String) async {
        await perform(on: repository, success: "toast.committed") {
            await GitService.commitAndPush(at: repository.url, message: message)
        }
    }

    func clean(_ repository: Repository) async {
        let urls = repository.cleanables.map { repository.url.appendingPathComponent($0.relativePath) }
        await perform(on: repository, success: "toast.cleaned") { await FileOperations.remove(urls) }
    }

    func clean(_ targets: [Repository]) async {
        for repository in targets where repository.cleanableSize > 0 {
            await clean(repository)
        }
        toast = .success(L("toast.cleanedMany", targets.count))
    }

    func push(_ targets: [Repository]) async {
        for repository in targets where repository.hasRemote {
            await push(repository)
        }
    }

    func trash(_ repository: Repository) async {
        busyIDs.insert(repository.id)
        let result = await FileOperations.trash(repository.url)
        busyIDs.remove(repository.id)
        guard result.succeeded else {
            toast = .failure(result.message)
            return
        }
        repositories.removeAll { $0.id == repository.id }
        toast = .success(L("toast.trashed", repository.name))
    }

    func trashSafe(_ targets: [Repository]) async {
        for repository in targets where repository.isSafeToDelete {
            await trash(repository)
        }
    }

    func backup(_ targets: [Repository]) async {
        guard !isVaultReady else {
            await backupToVault(targets)
            return
        }
        await exportBackup(targets)
    }

    func exportBackup(_ targets: [Repository]) async {
        guard let folder = settings.backupURL ?? chooseBackupFolder() else { return }
        let result = await Task.detached(priority: .userInitiated) {
            Result { try BackupService.backup(targets, to: folder) }
        }.value

        let location: URL
        do {
            location = try result.get()
        } catch {
            toast = .failure(error.localizedDescription)
            return
        }

        ledger.mark(targets)
        await inspect(targets.map(\.url))
        toast = .success(L("toast.backup", targets.count))
        SystemActions.revealInFinder(location)
    }

    func chooseBackupFolder() -> URL? {
        guard let url = SystemActions.chooseFolder(prompt: L("panel.backup"), startingAt: settings.backupURL) else { return nil }
        settings.backupFolder = url.path
        return url
    }

    private func perform(on repository: Repository, success key: String, _ operation: @escaping @Sendable () async -> CommandResult) async {
        busyIDs.insert(repository.id)
        let result = await operation()
        toast = result.succeeded ? .success(L(key, repository.name)) : .failure(result.message)
        await inspect([repository.url])
        busyIDs.remove(repository.id)
    }

    func inspect(_ urls: [URL]) async {
        let ledger = self.ledger
        var completed = 0
        await forEachConcurrently(urls) { url in
            await RepositoryInspector.inspect(url, ledgerHashes: ledger.hashes(for: url.path))
        } onResult: { [self] repository in
            upsert(repository)
            completed += 1
            scanProgress = Double(completed) / Double(max(urls.count, 1))
        }
    }

    private func upsert(_ repository: Repository) {
        guard let index = repositories.firstIndex(where: { $0.id == repository.id }) else {
            repositories.append(repository)
            return
        }
        repositories[index] = repository
    }

    private func forEachConcurrently<Item: Sendable, Output: Sendable>(
        _ items: [Item],
        work: @escaping @Sendable (Item) async -> Output,
        onResult: (Output) -> Void
    ) async {
        await withTaskGroup(of: Output.self) { group in
            var iterator = items.makeIterator()
            for _ in 0..<min(concurrency, items.count) {
                guard let item = iterator.next() else { break }
                group.addTask { await work(item) }
            }
            for await output in group {
                onResult(output)
                guard let item = iterator.next() else { continue }
                group.addTask { await work(item) }
            }
        }
    }
}

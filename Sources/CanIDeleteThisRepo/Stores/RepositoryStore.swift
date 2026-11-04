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
    var hasVaultKey = VaultCrypto.loadKey().map(VaultService.verify) ?? false
    var activities: [Activity] = []
    var backupRequest: BackupRequest?
    var savings = SavingsLedger.load()
    var ledger = BackupLedger.load()

    private let concurrency = 6

    init() {
        settings = AppSettings.load()
        guard DemoData.isEnabled else { return }
        repositories = DemoData.repositories
        activities = DemoData.activities
    }

    var totalSize: Int64 { repositories.reduce(0) { $0 + $1.size } }
    var totalCleanable: Int64 { repositories.reduce(0) { $0 + $1.cleanableSize } }
    var safeRepositories: [Repository] { repositories.filter(\.isSafeToDelete) }
    var cleanableRepositories: [Repository] { repositories.filter { $0.cleanableSize > 0 } }
    var pendingSecretCount: Int { repositories.reduce(0) { $0 + $1.pendingSecrets.count } }

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

        let id = beginActivity(L("activity.scan"), symbol: "magnifyingglass")
        updateActivity(id, detail: L("activity.scan.searching"))
        let roots = settings.rootURLs
        let excluded = Set(settings.excluded)
        let depth = settings.maxDepth
        let urls = await Task.detached(priority: .userInitiated) {
            RepositoryScanner.find(in: roots, excluding: excluded, maxDepth: depth)
        }.value

        let found = Set(urls.map(\.path))
        repositories.removeAll { !found.contains($0.id) }
        updateActivity(id, total: urls.count)
        await inspect(urls, activity: id)
        finishActivity(id, .success(L("activity.scan.done", urls.count)))
    }

    func refresh(_ repository: Repository) async {
        await inspect([repository.url])
    }

    func fetchAll() async {
        let targets = repositories.filter(\.hasRemote)
        guard !targets.isEmpty else { return }
        let id = beginActivity(L("activity.fetchAll"), symbol: "arrow.triangle.2.circlepath", total: targets.count)
        var completed = 0
        var failures: [String] = []
        await forEachConcurrently(targets) { repository in
            (repository.name, await GitService.fetch(at: repository.url))
        } onResult: { [self] name, result in
            completed += 1
            failures += result.succeeded ? [] : [name]
            updateActivity(id, detail: name, completed: completed)
        }
        updateActivity(id, detail: L("activity.refreshing"))
        await inspect(targets.map(\.url))
        guard failures.isEmpty else {
            finishActivity(id, .failure(L("activity.fetchAll.failed", failures.joined(separator: ", "))))
            return
        }
        finishActivity(id, .success(L("toast.fetchedAll")))
    }

    func fetch(_ repository: Repository) async {
        await runBatch([repository], title: L("activity.fetch"), symbol: "arrow.down.circle") { _ in
            L("toast.fetched", repository.name)
        } operation: { repository, _ in
            await GitService.fetch(at: repository.url)
        }
    }

    func push(_ repository: Repository) async {
        await push([repository])
    }

    func pushAll(_ repository: Repository) async {
        await runBatch([repository], title: L("activity.push"), symbol: "arrow.up.circle") { _ in
            L("toast.pushed", repository.name)
        } operation: { repository, _ in
            await GitService.pushAll(at: repository.url)
        }
    }

    func push(_ targets: [Repository]) async {
        let items = targets.filter(\.hasRemote)
        await runBatch(items, title: L("activity.push"), symbol: "arrow.up.circle") { activity in
            items.count == 1 ? L("toast.pushed", items[0].name) : L("activity.push.done", activity.total)
        } operation: { repository, _ in
            await GitService.push(at: repository.url)
        }
    }

    func commitAndPush(_ repository: Repository, message: String) async {
        await runBatch([repository], title: L("activity.commit"), symbol: "checkmark.circle") { _ in
            L("toast.committed", repository.name)
        } operation: { repository, _ in
            await GitService.commitAndPush(at: repository.url, message: message)
        }
    }

    func clean(_ repository: Repository) async {
        await clean([repository])
    }

    func clean(_ targets: [Repository]) async {
        let items = targets.filter { $0.cleanableSize > 0 }
        let goal = items.reduce(0) { $0 + $1.cleanableSize }
        await runBatch(items, title: L("activity.clean"), symbol: "sparkles", goal: goal) { activity in
            L("activity.freed", Format.bytes(activity.freed ?? 0))
        } operation: { [self] repository, id in
            await cleanItems(of: repository, activity: id)
        }
    }

    func trash(_ repository: Repository) async {
        await trash([repository])
    }

    func trashSafe(_ targets: [Repository]) async {
        await trash(targets.filter(\.isSafeToDelete))
    }

    func chooseBackupFolder() -> URL? {
        guard let url = SystemActions.chooseFolder(prompt: L("panel.backup"), startingAt: settings.backupURL) else { return nil }
        settings.backupFolder = url.path
        return url
    }

    func inspect(_ urls: [URL], activity: Activity.ID? = nil) async {
        let ledger = self.ledger
        var completed = 0
        await forEachConcurrently(urls) { url in
            await RepositoryInspector.inspect(url, ledgerHashes: ledger.hashes(for: url.path))
        } onResult: { [self] repository in
            upsert(repository)
            completed += 1
            scanProgress = Double(completed) / Double(max(urls.count, 1))
            guard let activity else { return }
            updateActivity(activity, detail: repository.name, completed: completed)
        }
    }

    private func trash(_ targets: [Repository]) async {
        let goal = targets.reduce(0) { $0 + $1.size }
        await runBatch(targets, title: L("activity.trash"), symbol: "trash", goal: goal) { activity in
            targets.count == 1
                ? L("toast.trashed", targets[0].name)
                : L("activity.trash.done", activity.total, Format.bytes(activity.freed ?? 0))
        } operation: { [self] repository, id in
            updateActivity(id, detail: L("activity.trash.item", repository.name))
            let result = await FileOperations.trash(repository.url)
            guard result.succeeded else { return result }
            repositories.removeAll { $0.id == repository.id }
            addFreed(repository.size, to: id)
            savings.log(repository.name, bytes: repository.size, kind: .trashed)
            return result
        }
    }

    private func cleanItems(of repository: Repository, activity id: Activity.ID) async -> CommandResult {
        var freed: Int64 = 0
        defer { savings.log(repository.name, bytes: freed, kind: .cleaned) }
        do {
            for item in repository.cleanables {
                updateActivity(id, detail: repository.name + " — " + item.relativePath)
                var reported: Int64 = 0
                for try await fraction in FileOperations.removeProgressively(repository.url.appendingPathComponent(item.relativePath)) {
                    let target = Int64(Double(item.size) * fraction)
                    addFreed(target - reported, to: id)
                    freed += target - reported
                    reported = target
                }
            }
            return .success
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func runBatch(
        _ targets: [Repository],
        title: String,
        symbol: String,
        goal: Int64? = nil,
        success: (Activity) -> String,
        operation: (Repository, Activity.ID) async -> CommandResult
    ) async {
        guard !targets.isEmpty else { return }
        let id = beginActivity(title, symbol: symbol, total: targets.count, goal: goal)
        var failures: [String] = []
        for (index, repository) in targets.enumerated() {
            updateActivity(id, detail: repository.name, completed: index)
            busyIDs.insert(repository.id)
            let result = await operation(repository, id)
            busyIDs.remove(repository.id)
            failures += result.succeeded ? [] : [result.message]
            updateActivity(id, completed: index + 1)
        }
        let remaining = targets.filter { target in repositories.contains { $0.id == target.id } }
        updateActivity(id, detail: L("activity.refreshing"))
        await inspect(remaining.map(\.url))
        guard failures.isEmpty, let activity = activity(id) else {
            finishActivity(id, .failure(failures.first ?? ""))
            return
        }
        finishActivity(id, .success(success(activity)))
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

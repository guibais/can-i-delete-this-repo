import Foundation

extension RepositoryStore {
    var preferredDestination: BackupDestination {
        isVaultReady ? settings.backupDestination ?? .vault : .folder
    }

    var prefersEncryption: Bool {
        canEncrypt && settings.vaultEncrypted ?? true
    }

    func requestBackup(_ targets: [Repository], origin: BackupOrigin = .main) {
        let items = targets.filter { !$0.sensitiveFiles.isEmpty }
        guard !items.isEmpty else {
            toast = .failure(L("backup.nothing"))
            return
        }
        backupRequest = BackupRequest(repositories: items, origin: origin)
    }

    func performBackup(_ request: BackupRequest, to destination: BackupDestination, encrypted: Bool) async {
        backupRequest = nil
        settings.backupDestination = destination
        guard destination == .vault else {
            await exportToFolder(request.repositories)
            return
        }
        settings.vaultEncrypted = encrypted
        await backupToVault(request.repositories, encrypted: encrypted)
    }

    func exportToFolder(_ targets: [Repository]) async {
        guard let folder = settings.backupURL ?? chooseBackupFolder() else { return }
        let id = beginActivity(L("activity.backup.folder"), symbol: "folder.badge.plus", total: targets.count)
        do {
            let root = try BackupService.prepare(in: folder)
            for (index, repository) in targets.enumerated() {
                updateActivity(id, detail: L("activity.backup.copying", repository.name), completed: index)
                try await runDetached { try BackupService.copySecrets(of: repository, to: root) }
                updateActivity(id, completed: index + 1)
            }
            updateActivity(id, detail: L("activity.backup.script"))
            try await runDetached { try BackupService.finalize(targets, at: root) }
            ledger.mark(targets)
            await inspect(targets.map(\.url))
            finishActivity(id, .success(L("toast.backup", targets.count)))
            SystemActions.revealInFinder(root)
        } catch {
            finishActivity(id, .failure(error.localizedDescription))
        }
    }
}

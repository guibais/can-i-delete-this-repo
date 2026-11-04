import CryptoKit
import Foundation

extension RepositoryStore {
    var isVaultReady: Bool {
        settings.vaultRemote != nil && VaultService.isCloned && VaultService.isInitialized
    }

    var canEncrypt: Bool { hasVaultKey && VaultService.hasKeyCheck }
    var vaultNeedsRecoveryKey: Bool { VaultService.hasKeyCheck && !hasVaultKey }
    var vaultWebURL: URL? { settings.vaultRemote.flatMap { GitRemote(name: "origin", url: $0).webURL } }
    var vaultHost: String { vaultWebURL?.host ?? "Git" }

    var recoveryKey: String? {
        VaultCrypto.loadKey().map(VaultCrypto.recoveryKey(for:))
    }

    func createVaultRepository(named name: String) async -> String? {
        let id = beginActivity(L("activity.vault.create"), symbol: "plus.rectangle.on.folder")
        updateActivity(id, detail: name)
        let (result, url) = await VaultService.createRepository(named: name)
        guard let url else {
            finishActivity(id, .failure(result.message.isEmpty ? L("vault.error.gh") : result.message))
            return nil
        }
        finishActivity(id, .success(L("activity.vault.created", name)))
        return url
    }

    func connectVault(remote: String) async -> VaultConnection {
        isVaultBusy = true
        defer { isVaultBusy = false }

        let id = beginActivity(L("activity.vault.connect"), symbol: "link")
        updateActivity(id, detail: L("activity.vault.checking"))
        guard await VaultService.visibility(of: remote) != .publicRepo else {
            finishActivity(id, .failure(L("vault.error.public")))
            return .failed(L("vault.error.public"))
        }

        updateActivity(id, detail: L("activity.vault.cloning", GitRemote(name: "origin", url: remote).webURL?.host ?? "Git"))
        if settings.vaultRemote != remote {
            VaultService.disconnect()
            hasVaultKey = false
        }
        let result = await VaultService.connect(remote: remote)
        guard result.succeeded else {
            finishActivity(id, .failure(result.message))
            return .failed(result.message)
        }
        settings.vaultRemote = remote
        finishActivity(id, .success(L("activity.vault.connected")))

        guard VaultService.isInitialized else { return .needsSetup }
        guard VaultService.hasKeyCheck else {
            await inspect(repositories.map(\.url))
            return .ready
        }
        guard let key = VaultCrypto.loadKey(), VaultService.verify(key) else { return .needsRecoveryKey }
        hasVaultKey = true
        await inspect(repositories.map(\.url))
        return .ready
    }

    func setupVault(encrypted: Bool) async -> String? {
        isVaultBusy = true
        defer { isVaultBusy = false }

        let id = beginActivity(L(encrypted ? "activity.vault.addKey" : "activity.vault.setup"), symbol: "lock.shield")
        let key = encrypted ? VaultCrypto.generateKey() : nil
        do {
            try VaultService.initialize(with: key)
        } catch {
            finishActivity(id, .failure(error.localizedDescription))
            return nil
        }
        if let key {
            VaultCrypto.saveKey(key)
            hasVaultKey = true
        }
        settings.vaultEncrypted = encrypted
        updateActivity(id, detail: L("activity.vault.uploading", vaultHost))
        let result = await publishVault(message: "chore: configure vault")
        finishActivity(id, result.succeeded ? .success(L("vault.toast.ready")) : .failure(result.message))
        return key.map(VaultCrypto.recoveryKey(for:))
    }

    func importVaultKey(_ recovery: String) async -> Bool {
        guard let key = VaultCrypto.key(fromRecovery: recovery), VaultService.verify(key) else { return false }
        VaultCrypto.saveKey(key)
        hasVaultKey = true
        await inspect(repositories.map(\.url))
        return true
    }

    func disconnectVault() {
        VaultService.disconnect()
        settings.vaultRemote = nil
        hasVaultKey = false
        Task { await inspect(repositories.map(\.url)) }
    }

    func syncVault() async {
        isVaultBusy = true
        defer { isVaultBusy = false }

        let id = beginActivity(L("activity.vault.sync"), symbol: "arrow.triangle.2.circlepath")
        updateActivity(id, detail: L("activity.vault.pulling", vaultHost))
        let pulled = await VaultService.pull()
        guard pulled.succeeded else {
            finishActivity(id, .failure(pulled.message))
            return
        }
        updateActivity(id, detail: L("activity.vault.uploading", vaultHost))
        let pushed = await publishVault(message: "chore: sync vault")
        updateActivity(id, detail: L("activity.refreshing"), total: repositories.count)
        await inspect(repositories.map(\.url), activity: id)
        finishActivity(id, pushed.succeeded ? .success(L("vault.toast.synced")) : .failure(pushed.message))
    }

    func backupToVault(_ targets: [Repository], encrypted: Bool) async {
        let key = encrypted ? VaultCrypto.loadKey() : nil
        guard isVaultReady, !encrypted || canEncrypt, !encrypted || key != nil else {
            toast = .failure(L(isVaultReady ? "vault.error.missingKey" : "vault.error.notReady"))
            return
        }
        isVaultBusy = true
        defer { isVaultBusy = false }

        let id = beginActivity(
            L(encrypted ? "activity.vault.backupEncrypted" : "activity.vault.backupPlain"),
            symbol: encrypted ? "lock.icloud" : "icloud.and.arrow.up",
            total: targets.count
        )
        updateActivity(id, detail: L("activity.vault.pulling", vaultHost))
        let pulled = await VaultService.pull()
        guard pulled.succeeded else {
            finishActivity(id, .failure(pulled.message))
            return
        }

        var files = 0
        var projects: [String] = []
        do {
            for (index, repository) in targets.enumerated() {
                updateActivity(id, detail: L(encrypted ? "activity.vault.encrypting" : "activity.vault.copying", repository.name), completed: index)
                busyIDs.insert(repository.id)
                defer { busyIDs.remove(repository.id) }
                let count = try await runDetached { try VaultService.backupRepository(repository, key: key, encrypt: encrypted) }
                files += count
                projects += count > 0 ? [repository.name] : []
                updateActivity(id, completed: index + 1)
            }
        } catch {
            finishActivity(id, .failure(error.localizedDescription))
            return
        }

        guard !projects.isEmpty else {
            finishActivity(id, .success(L("vault.toast.upToDate")))
            return
        }
        updateActivity(id, detail: L("activity.vault.uploading", vaultHost))
        let result = await publishVault(message: "backup: " + projects.joined(separator: ", "))
        await inspect(targets.map(\.url))
        finishActivity(id, result.succeeded ? .success(L("vault.toast.backedUp", files, projects.count)) : .failure(result.message))
    }

    func restoreFromVault(_ targets: [Repository]) async {
        isVaultBusy = true
        defer { isVaultBusy = false }

        let id = beginActivity(L("activity.vault.restore"), symbol: "icloud.and.arrow.down")
        updateActivity(id, detail: L("activity.vault.pulling", vaultHost))
        _ = await VaultService.pull()
        await inspect(targets.map(\.url))

        let fresh = repositories(for: Set(targets.map(\.id))).filter { !$0.restorableSecrets.isEmpty }
        let needsKey = fresh.contains { $0.restorableSecrets.contains { $0.encrypted == true } }
        let key = hasVaultKey ? VaultCrypto.loadKey() : nil
        guard !fresh.isEmpty else {
            finishActivity(id, .success(L("vault.toast.nothingToRestore")))
            return
        }
        guard !needsKey || key != nil else {
            finishActivity(id, .failure(L("vault.error.missingKey")))
            return
        }

        updateActivity(id, total: fresh.count)
        var restored = 0
        do {
            for (index, repository) in fresh.enumerated() {
                updateActivity(id, detail: L("activity.vault.restoring", repository.name), completed: index)
                restored += try await runDetached { try VaultService.restore(repository, key: key) }
            }
        } catch {
            finishActivity(id, .failure(error.localizedDescription))
            return
        }
        await inspect(fresh.map(\.url))
        finishActivity(id, .success(L("vault.toast.restored", restored)))
    }

    func cloneAndRestore(_ entry: VaultIndexEntry) async {
        guard let remote = entry.remote,
              let folder = SystemActions.chooseFolder(prompt: L("vault.panel.clone"))
        else { return }
        let destination = folder.appendingPathComponent(entry.name, isDirectory: true)
        let id = beginActivity(L("activity.vault.clone"), symbol: "square.and.arrow.down.on.square")
        updateActivity(id, detail: L("activity.vault.cloningProject", entry.name))
        let result = await GitService.git(["clone", remote, destination.path], at: folder)
        guard result.succeeded else {
            finishActivity(id, .failure(result.message))
            return
        }
        await inspect([destination])
        finishActivity(id, .success(L("activity.vault.cloned", entry.name)))
        guard let repository = repositories.first(where: { $0.url.standardizedFileURL == destination.standardizedFileURL }) else { return }
        await restoreFromVault([repository])
    }

    func vaultGitInfo() async -> VaultGitInfo? {
        guard VaultService.isCloned else { return nil }
        return await VaultService.gitInfo()
    }

    func localRepository(for entry: VaultIndexEntry) -> Repository? {
        repositories.first { VaultService.identity(for: $0.url, remotes: $0.snapshot.remotes) == entry.identity }
    }

    private func publishVault(message: String) async -> CommandResult {
        let committed = await VaultService.commit(message: message)
        guard committed.succeeded else { return committed }
        return await VaultService.push()
    }
}

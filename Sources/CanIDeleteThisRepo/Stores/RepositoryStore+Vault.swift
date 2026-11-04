import CryptoKit
import Foundation

extension RepositoryStore {
    var isVaultReady: Bool {
        settings.vaultRemote != nil && hasVaultKey && VaultService.isCloned
    }

    func createVaultRepository(named name: String) async -> String? {
        let (result, url) = await VaultService.createRepository(named: name)
        guard let url else {
            toast = .failure(result.message.isEmpty ? L("vault.error.gh") : result.message)
            return nil
        }
        return url
    }

    func connectVault(remote: String) async -> VaultConnection {
        isVaultBusy = true
        defer { isVaultBusy = false }

        guard await VaultService.visibility(of: remote) != .publicRepo else {
            return .failed(L("vault.error.public"))
        }

        let result = await VaultService.connect(remote: remote)
        guard result.succeeded else { return .failed(result.message) }
        settings.vaultRemote = remote

        guard VaultService.hasKeyCheck else { return .needsNewKey }
        guard let key = VaultCrypto.loadKey(), VaultService.verify(key) else { return .needsRecoveryKey }
        hasVaultKey = true
        await inspect(repositories.map(\.url))
        return .ready
    }

    func createVaultKey() async -> String? {
        isVaultBusy = true
        defer { isVaultBusy = false }

        let key = VaultCrypto.generateKey()
        do {
            try VaultService.initialize(with: key)
        } catch {
            toast = .failure(error.localizedDescription)
            return nil
        }
        VaultCrypto.saveKey(key)
        hasVaultKey = true
        let result = await VaultService.publish(message: "chore: initialize vault")
        toast = result.succeeded ? nil : .failure(result.message)
        return VaultCrypto.recoveryKey(for: key)
    }

    func importVaultKey(_ recovery: String) async -> Bool {
        guard let key = VaultCrypto.key(fromRecovery: recovery), VaultService.verify(key) else { return false }
        VaultCrypto.saveKey(key)
        hasVaultKey = true
        await inspect(repositories.map(\.url))
        return true
    }

    var recoveryKey: String? {
        VaultCrypto.loadKey().map(VaultCrypto.recoveryKey(for:))
    }

    func disconnectVault() {
        VaultService.disconnect()
        settings.vaultRemote = nil
        Task { await inspect(repositories.map(\.url)) }
    }

    func syncVault() async {
        await runVault {
            let result = await VaultService.pull()
            await inspect(repositories.map(\.url))
            toast = result.succeeded ? .success(L("vault.toast.synced")) : .failure(result.message)
        }
    }

    func backupToVault(_ targets: [Repository]) async {
        await runVault { key in
            let pulled = await VaultService.pull()
            guard pulled.succeeded else {
                toast = .failure(pulled.message)
                return
            }
            let summary: VaultBackupSummary
            do {
                summary = try await Task.detached(priority: .userInitiated) {
                    try VaultService.backup(targets, with: key)
                }.value
            } catch {
                toast = .failure(error.localizedDescription)
                return
            }
            guard !summary.projects.isEmpty else {
                toast = .success(L("vault.toast.upToDate"))
                return
            }
            let result = await VaultService.publish(message: "backup: " + summary.projects.joined(separator: ", "))
            await inspect(targets.map(\.url))
            toast = result.succeeded ? .success(L("vault.toast.backedUp", summary.files, summary.projects.count)) : .failure(result.message)
        }
    }

    func restoreFromVault(_ targets: [Repository]) async {
        await runVault { key in
            _ = await VaultService.pull()
            await inspect(targets.map(\.url))
            let fresh = repositories(for: Set(targets.map(\.id))).filter { !$0.restorableSecrets.isEmpty }
            let restored: Int
            do {
                restored = try await Task.detached(priority: .userInitiated) {
                    try fresh.reduce(0) { $0 + (try VaultService.restore($1, with: key)) }
                }.value
            } catch {
                toast = .failure(error.localizedDescription)
                return
            }
            await inspect(fresh.map(\.url))
            toast = .success(L("vault.toast.restored", restored))
        }
    }

    func cloneAndRestore(_ entry: VaultIndexEntry) async {
        guard let remote = entry.remote,
              let folder = SystemActions.chooseFolder(prompt: L("vault.panel.clone"))
        else { return }
        let destination = folder.appendingPathComponent(entry.name, isDirectory: true)
        isVaultBusy = true
        let result = await GitService.git(["clone", remote, destination.path], at: folder)
        isVaultBusy = false
        guard result.succeeded else {
            toast = .failure(result.message)
            return
        }
        await inspect([destination])
        guard let repository = repositories.first(where: { $0.url.standardizedFileURL == destination.standardizedFileURL }) else { return }
        await restoreFromVault([repository])
    }

    func localRepository(for entry: VaultIndexEntry) -> Repository? {
        repositories.first { VaultService.identity(for: $0.url, remotes: $0.snapshot.remotes) == entry.identity }
    }

    private func runVault(_ work: (SymmetricKey) async -> Void) async {
        guard let key = VaultCrypto.loadKey() else {
            toast = .failure(L("vault.error.missingKey"))
            return
        }
        isVaultBusy = true
        await work(key)
        isVaultBusy = false
    }

    private func runVault(_ work: () async -> Void) async {
        isVaultBusy = true
        await work()
        isVaultBusy = false
    }
}

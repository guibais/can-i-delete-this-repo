import SwiftUI

struct VaultSettings: View {
    @Environment(RepositoryStore.self) private var store
    @State private var isSettingUp = false
    @State private var setupAtRecovery = false
    @State private var showKey = false
    @State private var newKey: String?
    @State private var info: VaultGitInfo?
    @State private var confirm: ConfirmableAction?

    var body: some View {
        Form {
            if let remote = store.settings.vaultRemote {
                repositorySection(remote)
                gitSection
                securitySection
                manageSection
            } else {
                Section {
                    Text(L("vault.empty.message"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(L("vault.setup.title")) { openSetup(atRecovery: false) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isSettingUp) {
            VaultSetupSheet(startAtRecovery: setupAtRecovery).environment(store)
        }
        .confirmation($confirm)
        .task(id: store.isVaultBusy) { info = await store.vaultGitInfo() }
    }

    private func repositorySection(_ remote: String) -> some View {
        Section(L("vault.settings.repo")) {
            LabeledContent(L("vault.settings.remote")) {
                Text(remote).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
            }
            LabeledContent(L("vault.settings.local")) {
                Text(VaultService.root.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack {
                if let web = store.vaultWebURL {
                    Button(L("vault.action.openWeb")) { SystemActions.openWeb(web) }
                }
                Button(L("action.finder")) { SystemActions.revealInFinder(VaultService.root) }
                Button(L("vault.settings.openTerminal")) { SystemActions.openTerminal(VaultService.root) }
            }
            .disabled(!VaultService.isCloned)
        }
    }

    private var gitSection: some View {
        Section(L("vault.settings.git")) {
            if let info {
                LabeledContent(L("stat.branch"), value: info.branch ?? "—")
                LabeledContent(L("vault.settings.commits"), value: "\(info.commits)")
                LabeledContent(L("vault.settings.lastCommit")) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(info.lastCommitMessage ?? L("stat.never")).lineLimit(1)
                        if let date = info.lastCommitDate {
                            Text(Format.relative(date)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                LabeledContent(L("vault.settings.syncState")) { syncLabel(info) }
            } else {
                ProgressView().controlSize(.small)
            }
            Button { Task { await store.syncVault() } } label: {
                Label(L("vault.action.sync"), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!store.isVaultReady || store.isVaultBusy)
        }
    }

    private func syncLabel(_ info: VaultGitInfo) -> some View {
        let parts = [
            info.ahead > 0 ? L("vault.settings.ahead", info.ahead) : nil,
            info.behind > 0 ? L("vault.settings.behind", info.behind) : nil,
            info.pendingChanges > 0 ? L("vault.settings.pending", info.pendingChanges) : nil
        ].compactMap { $0 }
        return Label(
            parts.isEmpty ? L("vault.settings.upToDate") : parts.joined(separator: " · "),
            systemImage: parts.isEmpty ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle.fill"
        )
        .foregroundStyle(parts.isEmpty ? Color.green : Color.orange)
    }

    private var securitySection: some View {
        Section(L("vault.settings.security")) {
            LabeledContent(L("vault.settings.encryption")) {
                Label(
                    L(VaultService.hasKeyCheck ? "vault.settings.encryption.on" : "vault.settings.encryption.off"),
                    systemImage: VaultService.hasKeyCheck ? "lock.fill" : "lock.open"
                )
                .foregroundStyle(VaultService.hasKeyCheck ? Color.green : Color.orange)
            }
            LabeledContent(L("vault.settings.key")) {
                Label(L(keyStatusKey), systemImage: store.hasVaultKey ? "key.fill" : "key.slash")
            }
            Picker(L("vault.settings.defaultMode"), selection: encryptedDefault) {
                Text(L("vault.mode.encrypted")).tag(true)
                Text(L("vault.mode.plain")).tag(false)
            }
            .disabled(!store.canEncrypt)
            if let key = newKey ?? (showKey ? store.recoveryKey : nil) {
                RecoveryKeyView(key: key)
            }
            HStack {
                if store.hasVaultKey {
                    Button(L(showKey ? "vault.settings.hideKey" : "vault.settings.showKey")) { showKey.toggle() }
                }
                if store.vaultNeedsRecoveryKey {
                    Button(L("vault.setup.unlock")) { openSetup(atRecovery: true) }
                }
                if !VaultService.hasKeyCheck && store.isVaultReady {
                    Button(L("vault.settings.addKey")) { Task { newKey = await store.setupVault(encrypted: true) } }
                        .disabled(store.isVaultBusy)
                }
            }
        }
    }

    private func openSetup(atRecovery: Bool) {
        setupAtRecovery = atRecovery
        isSettingUp = true
    }

    private var keyStatusKey: String {
        guard store.hasVaultKey else { return VaultService.hasKeyCheck ? "vault.settings.keyMissing" : "vault.settings.keyNotNeeded" }
        return VaultCrypto.isKeySynced ? "vault.settings.keySynced" : "vault.settings.keyLocal"
    }

    private var encryptedDefault: Binding<Bool> {
        Binding(get: { store.prefersEncryption }, set: { store.settings.vaultEncrypted = $0 })
    }

    private var manageSection: some View {
        Section {
            HStack {
                Button(L("vault.settings.changeRemote")) { openSetup(atRecovery: false) }
                Spacer()
                Button(L("vault.settings.disconnect"), role: .destructive) {
                    confirm = ConfirmableAction(
                        title: L("vault.settings.disconnect"),
                        message: L("vault.settings.disconnectMessage"),
                        buttonTitle: L("vault.settings.disconnect")
                    ) { store.disconnectVault() }
                }
            }
        }
    }
}

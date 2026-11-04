import SwiftUI

struct VaultWindow: View {
    static let id = "vault"

    @Environment(RepositoryStore.self) private var store
    @State private var entries: [VaultIndexEntry] = []
    @State private var isSettingUp = false

    var body: some View {
        Group {
            if store.isVaultReady {
                list
            } else {
                ContentUnavailableView {
                    Label(L("vault.empty.title"), systemImage: "lock.shield")
                } description: {
                    Text(L("vault.empty.message"))
                } actions: {
                    Button(L("vault.setup.title")) { isSettingUp = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(L("vault.title"))
        .navigationSubtitle(store.settings.vaultRemote ?? "")
        .toolbar {
            ToolbarItemGroup {
                if store.isVaultBusy {
                    ProgressView().controlSize(.small)
                }
                Button { Task { await store.syncVault(); reload() } } label: {
                    Label(L("vault.action.sync"), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!store.isVaultReady || store.isVaultBusy)
                Button { Task { await store.backupToVault(store.repositories); reload() } } label: {
                    Label(L("vault.action.backupAll"), systemImage: "lock.icloud")
                }
                .disabled(!store.isVaultReady || store.isVaultBusy)
            }
        }
        .sheet(isPresented: $isSettingUp, onDismiss: reload) { VaultSetupSheet().environment(store) }
        .onAppear(perform: reload)
        .onChange(of: store.isVaultBusy) { reload() }
    }

    private var list: some View {
        List(entries) { entry in
            VaultEntryRow(entry: entry, local: store.localRepository(for: entry))
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(L("vault.list.empty"), systemImage: "tray")
            }
        }
    }

    private func reload() {
        entries = VaultService.index().projects.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct VaultEntryRow: View {
    @Environment(RepositoryStore.self) private var store
    let entry: VaultIndexEntry
    let local: Repository?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: local == nil ? "icloud" : "checkmark.icloud.fill")
                .font(.title2)
                .foregroundStyle(local == nil ? Color.blue : Color.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).fontWeight(.semibold)
                Text(entry.identity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(L("vault.list.files", entry.fileCount)).font(.caption)
                Text(Format.relative(entry.updatedAt)).font(.caption).foregroundStyle(.secondary)
            }
            action
                .controlSize(.small)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var action: some View {
        if let local {
            Button(L("vault.action.restore")) { Task { await store.restoreFromVault([local]) } }
                .disabled(local.restorableSecrets.isEmpty)
        } else {
            Button(L("vault.action.cloneRestore")) { Task { await store.cloneAndRestore(entry) } }
                .buttonStyle(.borderedProminent)
                .disabled(entry.remote == nil)
        }
    }
}

struct VaultSettings: View {
    @Environment(RepositoryStore.self) private var store
    @State private var isSettingUp = false
    @State private var showKey = false

    var body: some View {
        Form {
            Section {
                Text(L("vault.empty.message"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let remote = store.settings.vaultRemote {
                Section(L("vault.settings.repo")) {
                    LabeledContent(L("vault.settings.remote"), value: remote)
                    LabeledContent(L("vault.settings.key")) {
                        Label(
                            L(store.hasVaultKey ? (VaultCrypto.isKeySynced ? "vault.settings.keySynced" : "vault.settings.keyLocal") : "vault.settings.keyMissing"),
                            systemImage: store.hasVaultKey ? "key.fill" : "key.slash"
                        )
                    }
                    if showKey, let key = store.recoveryKey {
                        RecoveryKeyView(key: key)
                    }
                    HStack {
                        Button(L(showKey ? "vault.settings.hideKey" : "vault.settings.showKey")) { showKey.toggle() }
                            .disabled(!store.hasVaultKey)
                        if !store.isVaultReady {
                            Button(L("vault.setup.title")) { isSettingUp = true }
                        }
                        Spacer()
                        Button(L("vault.settings.disconnect"), role: .destructive) { store.disconnectVault() }
                    }
                }
            } else {
                Section {
                    Button(L("vault.setup.title")) { isSettingUp = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isSettingUp) { VaultSetupSheet().environment(store) }
    }
}

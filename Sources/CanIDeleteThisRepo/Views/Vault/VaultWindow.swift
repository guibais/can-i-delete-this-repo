import SwiftUI

struct VaultWindow: View {
    static let id = "vault"

    @Environment(RepositoryStore.self) private var store
    @State private var entries: [VaultIndexEntry] = []
    @State private var search = ""
    @State private var isSettingUp = false

    private var filtered: [VaultIndexEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.identity.localizedCaseInsensitiveContains(query) }
    }

    private var onMac: [VaultIndexEntry] { filtered.filter { store.localRepository(for: $0) != nil } }
    private var elsewhere: [VaultIndexEntry] { filtered.filter { store.localRepository(for: $0) == nil } }

    var body: some View {
        Group {
            if store.isVaultReady {
                content
                    .searchable(text: $search, prompt: L("vault.search"))
            } else {
                emptyState
            }
        }
        .navigationTitle(L("vault.title"))
        .navigationSubtitle(store.vaultWebURL.map { ($0.host ?? "") + $0.path } ?? "")
        .toolbar { VaultToolbar() }
        .statusOverlay()
        .sheet(isPresented: $isSettingUp, onDismiss: reload) {
            VaultSetupSheet(startAtRecovery: store.vaultNeedsRecoveryKey).environment(store)
        }
        .sheet(item: store.backupRequestBinding(for: .vault)) { request in
            BackupSheet(request: request).environment(store)
        }
        .onAppear(perform: reload)
        .onChange(of: store.isVaultBusy) { reload() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("vault.empty.title"), systemImage: "lock.shield")
        } description: {
            Text(L("vault.empty.message"))
        } actions: {
            Button(L("vault.setup.title")) { isSettingUp = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.vaultNeedsRecoveryKey {
                    HStack {
                        InfoBanner(text: L("backup.keyLocked"), symbol: "key.slash")
                        Button(L("vault.setup.unlock")) { isSettingUp = true }
                    }
                }
                summary
                if entries.isEmpty {
                    ContentUnavailableView(L("vault.list.empty"), systemImage: "tray", description: Text(L("vault.list.emptyHint")))
                }
                section(L("vault.section.onMac"), symbol: "laptopcomputer", items: onMac)
                section(L("vault.section.elsewhere"), symbol: "icloud", items: elsewhere)
            }
            .padding(20)
        }
    }

    private var summary: some View {
        let files = entries.reduce(0) { $0 + $1.fileCount }
        let last = entries.map(\.updatedAt).max()
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            StatTile(title: L("vault.summary.projects"), value: "\(entries.count)", symbol: "folder.fill")
            StatTile(title: L("vault.summary.files"), value: "\(files)", symbol: "doc.on.doc.fill", tint: .yellow)
            StatTile(title: L("vault.summary.last"), value: last.map(Format.relative) ?? L("stat.never"), symbol: "clock.fill", tint: .blue)
            StatTile(
                title: L("vault.summary.mode"),
                value: L(store.canEncrypt ? "vault.mode.encrypted" : store.vaultNeedsRecoveryKey ? "vault.mode.locked" : "vault.mode.plain"),
                symbol: store.canEncrypt ? "lock.fill" : "lock.open.fill",
                tint: store.canEncrypt ? .green : .orange
            )
        }
    }

    @ViewBuilder
    private func section(_ title: String, symbol: String, items: [VaultIndexEntry]) -> some View {
        if !items.isEmpty {
            SectionCard(title: title, symbol: symbol) {
                Text("\(items.count)").foregroundStyle(.secondary).monospacedDigit()
            } content: {
                ForEach(items) { entry in
                    VaultEntryRow(entry: entry, local: store.localRepository(for: entry))
                    if entry.id != items.last?.id { Divider() }
                }
            }
        }
    }

    private func reload() {
        entries = VaultService.index().projects.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct VaultToolbar: ToolbarContent {
    @Environment(RepositoryStore.self) private var store

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button { Task { await store.syncVault() } } label: {
                Label(L("vault.action.sync"), systemImage: "arrow.triangle.2.circlepath")
            }
            .help(L("vault.action.sync"))
            .disabled(!store.isVaultReady || store.isVaultBusy)

            Button { store.requestBackup(store.repositories, origin: .vault) } label: {
                Label(L("vault.action.backupAll"), systemImage: "lock.icloud")
            }
            .help(L("vault.action.backupAll"))
            .disabled(!store.isVaultReady || store.isVaultBusy)

            if let web = store.vaultWebURL {
                Button { SystemActions.openWeb(web) } label: {
                    Label(L("vault.action.openWeb"), systemImage: "safari")
                }
                .help(L("vault.action.openWeb"))
            }

            SettingsLink {
                Label(L("settings.open"), systemImage: "gearshape")
            }
            .help(L("settings.open"))
        }
    }
}

private struct VaultEntryRow: View {
    @Environment(RepositoryStore.self) private var store
    let entry: VaultIndexEntry
    let local: Repository?
    @State private var isExpanded = false
    @State private var files: [(path: String, entry: VaultEntry)] = []

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(files, id: \.path) { file in
                    HStack(spacing: 8) {
                        Image(systemName: file.entry.encrypted ? "lock.fill" : "lock.open")
                            .foregroundStyle(file.entry.encrypted ? Color.green : Color.orange)
                            .frame(width: 16)
                        Text(file.path).font(.callout.monospaced())
                        Spacer()
                        Text(Format.bytes(file.entry.size) + " · " + file.entry.machine + " · " + Format.relative(file.entry.updatedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 28)
            .padding(.top, 6)
        } label: {
            header
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            files = (VaultService.manifest(for: entry.identity)?.files ?? [:])
                .map { ($0.key, $0.value) }
                .sorted { $0.path < $1.path }
        }
        .padding(.vertical, 2)
    }

    private var header: some View {
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
                syncState
            }
            actions
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var syncState: some View {
        if let local, !local.pendingSecrets.isEmpty {
            Text(L("vault.state.toBackUp", local.pendingSecrets.count)).font(.caption).foregroundStyle(.orange)
        } else if let local, !local.restorableSecrets.isEmpty {
            Text(L("vault.state.toRestore", local.restorableSecrets.count)).font(.caption).foregroundStyle(.blue)
        } else {
            Text(Format.relative(entry.updatedAt)).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let local {
            Button { store.requestBackup([local], origin: .vault) } label: {
                Label(L("vault.action.backup"), systemImage: "icloud.and.arrow.up")
            }
            .disabled(local.sensitiveFiles.isEmpty || store.isVaultBusy)
            Button { Task { await store.restoreFromVault([local]) } } label: {
                Label(L("vault.action.restoreShort"), systemImage: "icloud.and.arrow.down")
            }
            .disabled(local.restorableSecrets.isEmpty || store.isVaultBusy)
        } else {
            Button(L("vault.action.cloneRestore")) { Task { await store.cloneAndRestore(entry) } }
                .buttonStyle(.borderedProminent)
                .disabled(entry.remote == nil || store.isVaultBusy)
        }
    }
}

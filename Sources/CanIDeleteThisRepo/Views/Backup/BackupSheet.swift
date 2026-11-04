import SwiftUI

struct BackupSheet: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: BackupRequest
    @State private var destination: BackupDestination = .folder
    @State private var encrypted = true
    @State private var isSettingUpVault = false
    @State private var newKey: String?

    private var canStart: Bool {
        destination == .folder || store.isVaultReady && (!encrypted || store.canEncrypt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Text(L("backup.destination")).font(.headline)
            HStack(spacing: 12) {
                ChoiceCard(
                    title: L("backup.vault"),
                    subtitle: store.isVaultReady ? L("backup.vault.subtitle", store.vaultHost) : L("backup.vault.notReady"),
                    symbol: "lock.icloud.fill",
                    tint: .indigo,
                    isSelected: destination == .vault
                ) { destination = .vault }
                ChoiceCard(
                    title: L("backup.folder"),
                    subtitle: L("backup.folder.subtitle"),
                    symbol: "folder.fill",
                    tint: .blue,
                    isSelected: destination == .folder
                ) { destination = .folder }
            }
            options
            footer
        }
        .padding(24)
        .frame(width: 560)
        .animation(.snappy, value: destination)
        .animation(.snappy, value: encrypted)
        .onAppear {
            destination = store.preferredDestination
            encrypted = store.prefersEncryption || store.settings.vaultEncrypted ?? true
        }
        .sheet(isPresented: $isSettingUpVault) {
            VaultSetupSheet(startAtRecovery: store.vaultNeedsRecoveryKey).environment(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L("backup.title"), systemImage: "externaldrive.badge.checkmark")
                .font(.title2.weight(.bold))
                .symbolRenderingMode(.hierarchical)
            Text(L("backup.subtitle", request.fileCount, request.repositories.count))
                .foregroundStyle(.secondary)
            Text(request.repositories.map(\.name).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var options: some View {
        if destination == .folder {
            folderOptions
        } else if store.isVaultReady {
            vaultOptions
        } else {
            InfoBanner(text: L("backup.vault.setupHint"), symbol: "lock.shield", tint: .indigo)
            Button(L("vault.setup.title")) { isSettingUpVault = true }
        }
    }

    private var folderOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(store.settings.backupFolder ?? L("settings.backupFolder.none"), systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L("action.choose")) { _ = store.chooseBackupFolder() }
            }
            Text(L("backup.folder.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var vaultOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("backup.security")).font(.headline)
            HStack(spacing: 12) {
                ChoiceCard(
                    title: L("vault.mode.encrypted"),
                    subtitle: L("vault.mode.encrypted.subtitle"),
                    symbol: "lock.fill",
                    tint: .green,
                    isSelected: encrypted
                ) { encrypted = true }
                ChoiceCard(
                    title: L("vault.mode.plain"),
                    subtitle: L("vault.mode.plain.subtitle"),
                    symbol: "lock.open.fill",
                    tint: .orange,
                    isSelected: !encrypted
                ) { encrypted = false }
            }
            keyStatus
        }
    }

    @ViewBuilder
    private var keyStatus: some View {
        if let newKey {
            Text(L("vault.setup.keyMessage")).font(.caption).foregroundStyle(.secondary)
            RecoveryKeyView(key: newKey)
        } else if !encrypted {
            InfoBanner(text: L("backup.plainWarning"), symbol: "exclamationmark.triangle.fill")
        } else if store.vaultNeedsRecoveryKey {
            InfoBanner(text: L("backup.keyLocked"), symbol: "key.slash")
            Button(L("vault.setup.unlock")) { isSettingUpVault = true }
        } else if !store.canEncrypt {
            InfoBanner(text: L("backup.keyMissing"), symbol: "key", tint: .indigo)
            Button(L("vault.settings.addKey")) { Task { newKey = await store.setupVault(encrypted: true) } }
                .disabled(store.isVaultBusy)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L("action.cancel"), role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(L("backup.start", request.fileCount)) {
                let choice = (destination, encrypted)
                Task { await store.performBackup(request, to: choice.0, encrypted: choice.1) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canStart)
        }
    }
}

extension RepositoryStore {
    func backupRequestBinding(for origin: BackupOrigin) -> Binding<BackupRequest?> {
        Binding(
            get: { self.backupRequest?.origin == origin ? self.backupRequest : nil },
            set: { self.backupRequest = $0 }
        )
    }
}

import SwiftUI

private enum SetupStage {
    case choose
    case newKey(String)
    case recovery
}

struct VaultSetupSheet: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var stage: SetupStage = .choose
    @State private var useExisting = false
    @State private var repoName = "secrets-vault"
    @State private var remote = ""
    @State private var recovery = ""
    @State private var savedKey = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("vault.setup.title"), systemImage: "lock.shield.fill")
                .font(.title2.weight(.bold))
                .symbolRenderingMode(.hierarchical)
            content
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 500)
        .disabled(store.isVaultBusy)
        .overlay { if store.isVaultBusy { ProgressView() } }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choose: chooseView
        case .newKey(let key): newKeyView(key)
        case .recovery: recoveryView
        }
    }

    private var chooseView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("vault.setup.message"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("", selection: $useExisting) {
                Text(L("vault.setup.create")).tag(false)
                Text(L("vault.setup.existing")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if useExisting {
                TextField(L("vault.setup.urlPlaceholder"), text: $remote)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(L("vault.setup.namePlaceholder"), text: $repoName)
                    .textFieldStyle(.roundedBorder)
                Text(L("vault.setup.ghHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            buttons(primary: L("onboarding.continue"), disabled: useExisting ? remote.isEmpty : repoName.isEmpty) {
                Task { await connect() }
            }
        }
    }

    private func newKeyView(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("vault.setup.keyMessage"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            RecoveryKeyView(key: key)
            Toggle(L("vault.setup.saved"), isOn: $savedKey)
            buttons(primary: L("vault.setup.done"), disabled: !savedKey) { dismiss() }
        }
    }

    private var recoveryView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("vault.setup.recoveryMessage"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("XXXXXXXX-XXXXXXXX-…", text: $recovery)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            buttons(primary: L("vault.setup.unlock"), disabled: recovery.isEmpty) {
                Task { await unlock() }
            }
        }
    }

    private func buttons(primary: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(L("action.cancel"), role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(primary, action: action)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(disabled)
        }
    }

    private func connect() async {
        error = nil
        let url = useExisting ? remote.trimmingCharacters(in: .whitespaces) : await store.createVaultRepository(named: repoName)
        guard let url else { return }
        let connection = await store.connectVault(remote: url)
        await handle(connection)
    }

    private func handle(_ connection: VaultConnection) async {
        if case .failed(let message) = connection {
            error = message
            return
        }
        if connection == .needsRecoveryKey {
            stage = .recovery
            return
        }
        if connection == .ready {
            dismiss()
            return
        }
        guard let key = await store.createVaultKey() else { return }
        stage = .newKey(key)
    }

    private func unlock() async {
        guard await store.importVaultKey(recovery) else {
            error = L("vault.error.wrongKey")
            return
        }
        dismiss()
    }
}

struct RecoveryKeyView: View {
    let key: String

    var body: some View {
        HStack {
            Text(key)
                .font(.callout.monospaced().weight(.semibold))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help(L("vault.copy"))
        }
        .padding(12)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.yellow.opacity(0.4)))
    }
}

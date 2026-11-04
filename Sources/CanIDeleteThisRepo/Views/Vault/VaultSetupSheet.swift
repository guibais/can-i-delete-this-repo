import SwiftUI

private enum SetupStage: Equatable {
    case choose
    case mode
    case newKey(String)
    case recovery
}

struct VaultSetupSheet: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var startAtRecovery = false
    @State private var stage: SetupStage = .choose
    @State private var useExisting = false
    @State private var repoName = "secrets-vault"
    @State private var remote = ""
    @State private var recovery = ""
    @State private var encrypted = true
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
        .frame(width: 540)
        .disabled(store.isVaultBusy)
        .statusOverlay()
        .animation(.snappy, value: stage)
        .onAppear { stage = startAtRecovery ? .recovery : .choose }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choose: chooseView
        case .mode: modeView
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

    private var modeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("vault.setup.modeMessage"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            if !encrypted {
                InfoBanner(text: L("backup.plainWarning"), symbol: "exclamationmark.triangle.fill")
            }
            buttons(primary: L("onboarding.continue"), disabled: false) {
                Task { await configure() }
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
            Text(L("vault.setup.withoutKeyHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
            buttons(primary: L("vault.setup.unlock"), disabled: recovery.isEmpty, secondary: L("vault.setup.continueWithoutKey")) {
                Task { await unlock() }
            }
        }
    }

    private func buttons(primary: String, disabled: Bool, secondary: String? = nil, action: @escaping () -> Void) -> some View {
        HStack {
            if let secondary {
                Button(secondary) { dismiss() }
            }
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
        handle(await store.connectVault(remote: url))
    }

    private func handle(_ connection: VaultConnection) {
        let stages: [VaultConnection: SetupStage] = [.needsSetup: .mode, .needsRecoveryKey: .recovery]
        if case .failed(let message) = connection {
            error = message
            return
        }
        guard let next = stages[connection] else {
            dismiss()
            return
        }
        stage = next
    }

    private func configure() async {
        let key = await store.setupVault(encrypted: encrypted)
        guard encrypted, let key else {
            dismiss()
            return
        }
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

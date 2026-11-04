import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(L("settings.general"), systemImage: "gearshape") }
            ScanSettings()
                .tabItem { Label(L("settings.scan"), systemImage: "magnifyingglass") }
            VaultSettings()
                .tabItem { Label(L("vault.title"), systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 420)
    }
}

private struct GeneralSettings: View {
    @Environment(RepositoryStore.self) private var store
    @AppStorage("onboarding.completed") private var onboardingCompleted = true
    @AppStorage(Localization.languageKey) private var language = Localization.systemLanguage

    var body: some View {
        Form {
            Section {
                Picker(L("settings.language"), selection: $language) {
                    ForEach(Localization.supported, id: \.self) { code in
                        Text(L("language.\(code)")).tag(code)
                    }
                }
                .onChange(of: language) { _, value in Localization.apply(value) }
                Text(L("settings.language.restart"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L("settings.showOnboarding")) { onboardingCompleted = false }
            }

            Section(L("settings.backupFolder")) {
                HStack {
                    Text(store.settings.backupFolder ?? L("settings.backupFolder.none"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("action.choose")) { _ = store.chooseBackupFolder() }
                    if store.settings.backupFolder != nil {
                        Button(L("action.reset")) { store.settings.backupFolder = nil }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ScanSettings: View {
    @Environment(RepositoryStore.self) private var store

    private var exclusions: Binding<String> {
        Binding(
            get: { store.settings.excluded.joined(separator: ", ") },
            set: { store.settings.excluded = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    var body: some View {
        @Bindable var store = store
        Form {
            Section(L("settings.roots")) {
                ForEach(store.settings.roots, id: \.self) { root in
                    HStack {
                        Label(root.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                        Spacer()
                        Button { store.settings.roots.removeAll { $0 == root } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(L("action.addFolder"), action: addRoot)
            }

            Section {
                Stepper(L("settings.depth", store.settings.maxDepth), value: $store.settings.maxDepth, in: 2...12)
                TextField(L("settings.exclusions"), text: exclusions, axis: .vertical)
                    .lineLimit(2...4)
                Text(L("settings.exclusions.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addRoot() {
        guard let url = SystemActions.chooseFolder(prompt: L("panel.root")), !store.settings.roots.contains(url.path) else { return }
        store.settings.roots.append(url.path)
    }
}

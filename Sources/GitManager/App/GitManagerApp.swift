import SwiftUI

@main
struct GitManagerApp: App {
    @State private var store = RepositoryStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 1080, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L("action.scan")) { Task { await store.scan() } }
                    .keyboardShortcut("r")
                Button(L("action.fetchAll")) { Task { await store.fetchAll() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Window(L("vault.title"), id: VaultWindow.id) {
            VaultWindow()
                .environment(store)
                .frame(minWidth: 620, minHeight: 440)
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

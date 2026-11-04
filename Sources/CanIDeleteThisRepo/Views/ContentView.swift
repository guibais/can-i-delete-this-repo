import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @State private var filter: SidebarFilter? = DemoData.initialFilter
    @State private var selection: Set<Repository.ID> = Set(DemoData.repositories.filter { $0.name == DemoData.selectedName }.map(\.id))
    @State private var search = ""
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    private var activeFilter: SidebarFilter { filter ?? .home }

    private var visibleRepositories: [Repository] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return store.repositories.filter { repository in
            activeFilter.matches(repository) && (query.isEmpty || repository.displayPath.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        Group {
            if activeFilter == .home {
                homeLayout
            } else {
                listLayout
            }
        }
        .toolbar { MainToolbar() }
        .statusOverlay()
        .task { await initialScan() }
        .onChange(of: filter) { selection = [] }
        .sheet(item: store.backupRequestBinding(for: .main)) { request in
            BackupSheet(request: request).environment(store)
        }
        .sheet(isPresented: showOnboarding) {
            OnboardingView { onboardingCompleted = true; Task { await store.scan() } }
                .environment(store)
                .interactiveDismissDisabled()
        }
    }

    private var homeLayout: some View {
        NavigationSplitView {
            SidebarView(filter: $filter)
        } detail: {
            DashboardView { filter = $0 }
                .navigationTitle(L(SidebarFilter.home.titleKey))
                .navigationSubtitle(L("summary.repos", store.repositories.count))
        }
    }

    private var listLayout: some View {
        NavigationSplitView {
            SidebarView(filter: $filter)
        } content: {
            RepositoryListView(filter: activeFilter, repositories: visibleRepositories, selection: $selection)
                .navigationTitle(L(activeFilter.titleKey))
                .navigationSubtitle(L("summary.repos", visibleRepositories.count))
                .searchable(text: $search, placement: .toolbar, prompt: L("search.prompt"))
                .navigationSplitViewColumnWidth(min: 460, ideal: 620)
        } detail: {
            DetailContainer(selection: selection)
                .navigationSplitViewColumnWidth(min: 380, ideal: 460)
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding(get: { !onboardingCompleted && (!DemoData.isEnabled || DemoData.selectedName == "onboarding") }, set: { onboardingCompleted = !$0 })
    }

    private func initialScan() async {
        guard onboardingCompleted, store.repositories.isEmpty else { return }
        await store.scan()
    }
}

private struct MainToolbar: ToolbarContent {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            SettingsLink {
                Label(L("settings.open"), systemImage: "gearshape")
            }
            .help(L("settings.open"))

            Button { openWindow(id: VaultWindow.id) } label: {
                Label(L("vault.title"), systemImage: "lock.shield")
            }
            .help(L("vault.title"))

            Button { Task { await store.fetchAll() } } label: {
                Label(L("action.fetchAll"), systemImage: "arrow.triangle.2.circlepath")
            }
            .help(L("action.fetchAll"))
            .disabled(store.isScanning)

            Button { Task { await store.scan() } } label: {
                Label(L("action.scan"), systemImage: "magnifyingglass")
            }
            .help(L("action.scan"))
            .disabled(store.isScanning)
        }
    }
}

private struct DetailContainer: View {
    @Environment(RepositoryStore.self) private var store
    let selection: Set<Repository.ID>

    var body: some View {
        let selected = store.repositories(for: selection)
        if selected.count > 1 {
            BulkActionsView(repositories: selected)
        } else if let repository = selected.first {
            RepositoryDetailView(repository: repository)
        } else {
            ContentUnavailableView(L("detail.empty.title"), systemImage: "sidebar.right", description: Text(L("detail.empty.message")))
        }
    }
}

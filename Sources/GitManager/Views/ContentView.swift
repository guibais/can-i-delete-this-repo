import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @State private var filter: SidebarFilter? = .all
    @State private var selection: Set<Repository.ID> = Set(DemoData.repositories.filter { $0.name == DemoData.selectedName }.map(\.id))
    @State private var search = ""
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    private var visibleRepositories: [Repository] {
        let activeFilter = filter ?? .all
        let query = search.trimmingCharacters(in: .whitespaces)
        return store.repositories.filter { repository in
            activeFilter.matches(repository) && (query.isEmpty || repository.displayPath.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(filter: $filter)
        } content: {
            RepositoryListView(filter: filter ?? .all, repositories: visibleRepositories, selection: $selection)
                .navigationTitle(L((filter ?? .all).titleKey))
                .navigationSubtitle(L("summary.repos", visibleRepositories.count))
                .searchable(text: $search, placement: .toolbar, prompt: L("search.prompt"))
                .navigationSplitViewColumnWidth(min: 460, ideal: 620)
        } detail: {
            DetailContainer(selection: selection)
                .navigationSplitViewColumnWidth(min: 380, ideal: 460)
        }
        .toolbar { MainToolbar() }
        .overlay(alignment: .bottom) { toastOverlay }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .task(id: store.toast?.id) { await dismissToast() }
        .task { await initialScan() }
        .onChange(of: filter) { selection = [] }
        .sheet(isPresented: showOnboarding) {
            OnboardingView { onboardingCompleted = true; Task { await store.scan() } }
                .environment(store)
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = store.toast {
            ToastView(toast: toast)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func dismissToast() async {
        guard store.toast != nil else { return }
        try? await Task.sleep(for: .seconds(4))
        store.toast = nil
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

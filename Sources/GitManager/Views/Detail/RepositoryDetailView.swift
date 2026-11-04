import SwiftUI

struct RepositoryDetailView: View {
    @Environment(RepositoryStore.self) private var store
    let repository: Repository
    @State private var confirm: ConfirmableAction?
    @State private var isCommitting = false

    private var isBusy: Bool { store.busyIDs.contains(repository.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailHeader(repository: repository)
                StatusBanner(repository: repository)
                StatsGrid(repository: repository)
                if !repository.issues.isEmpty {
                    IssuesSection(issues: repository.issues)
                }
                RemotesSection(remotes: repository.snapshot.remotes)
                SecretsSection(repository: repository)
                CleanableSection(repository: repository) { confirmClean() }
                DangerSection { confirmTrash() }
            }
            .padding(24)
        }
        .disabled(isBusy)
        .toolbar { toolbar }
        .sheet(isPresented: $isCommitting) {
            CommitSheet(repository: repository)
        }
        .confirmation($confirm)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            if isBusy {
                ProgressView().controlSize(.small)
            }

            Button { Task { await store.fetch(repository) } } label: {
                Label(L("action.fetch"), systemImage: "arrow.down.circle")
            }
            .help(L("action.fetch"))
            .disabled(!repository.hasRemote)

            Button { isCommitting = true } label: {
                Label(L("action.commit"), systemImage: "checkmark.circle")
            }
            .help(L("action.commit"))
            .disabled(repository.snapshot.changes == 0 || !repository.hasRemote)

            Menu {
                Button(L("action.pushAll")) { Task { await store.pushAll(repository) } }
            } label: {
                Label(L("action.push"), systemImage: "arrow.up.circle")
            } primaryAction: {
                Task { await store.push(repository) }
            }
            .help(L("action.push"))
            .disabled(!repository.hasRemote)
        }
    }

    private func confirmClean() {
        confirm = ConfirmableAction(
            title: L("confirm.clean.title", repository.name),
            message: L("confirm.clean.message", Format.bytes(repository.cleanableSize)),
            buttonTitle: L("action.clean")
        ) { Task { await store.clean(repository) } }
    }

    private func confirmTrash() {
        confirm = ConfirmableAction(
            title: L("confirm.trash.title", repository.name),
            message: L(repository.isSafeToDelete ? "confirm.trash.safe" : "confirm.trash.unsafe"),
            buttonTitle: L("action.trash")
        ) { Task { await store.trash(repository) } }
    }
}

private struct DetailHeader: View {
    let repository: Repository

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RepositoryIcon(severity: repository.severity, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(repository.displayPath)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
        }

        HStack(spacing: 8) {
            OpenButton(title: L("action.finder"), symbol: "folder") { SystemActions.revealInFinder(repository.url) }
            OpenButton(title: L("action.terminal"), symbol: "terminal") { SystemActions.openTerminal(repository.url) }
            OpenButton(title: L("action.editor"), symbol: "chevron.left.forwardslash.chevron.right") { SystemActions.openEditor(repository.url) }
            if let web = repository.snapshot.remotes.first?.webURL {
                OpenButton(title: L("action.openRemote"), symbol: "safari") { SystemActions.openWeb(web) }
            }
        }
    }
}

private struct OpenButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

private struct StatusBanner: View {
    let repository: Repository

    var body: some View {
        let style = repository.severity.style
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.symbol)
                .font(.title2)
                .foregroundStyle(style.color)
                .symbolEffect(.bounce, value: repository.severity)
            VStack(alignment: .leading, spacing: 4) {
                Text(L(style.bannerKey + ".title")).font(.headline)
                Text(L(style.bannerKey + ".message"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(style.color.opacity(0.25)))
    }
}

private struct StatsGrid: View {
    let repository: Repository

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            StatTile(title: L("stat.size"), value: Format.bytes(repository.size), symbol: "internaldrive")
            StatTile(title: L("stat.cleanable"), value: Format.bytes(repository.cleanableSize), symbol: "sparkles", tint: .purple)
            StatTile(title: L("stat.branch"), value: repository.snapshot.branch ?? L("stat.detached"), symbol: "arrow.triangle.branch", tint: .teal)
            StatTile(
                title: L("stat.lastCommit"),
                value: repository.snapshot.lastCommit.map(Format.relative) ?? L("stat.never"),
                symbol: "clock",
                tint: .indigo
            )
        }
    }
}

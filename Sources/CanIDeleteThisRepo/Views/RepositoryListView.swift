import SwiftUI

struct RepositoryListView: View {
    @Environment(RepositoryStore.self) private var store
    let filter: SidebarFilter
    let repositories: [Repository]
    @Binding var selection: Set<Repository.ID>
    @State private var sortOrder = [KeyPathComparator(\Repository.size, order: .reverse)]

    private var sorted: [Repository] { repositories.sorted(using: sortOrder) }

    var body: some View {
        Group {
            if repositories.isEmpty && !store.isScanning {
                emptyState
            } else {
                table
                    .safeAreaInset(edge: .top, spacing: 0) {
                        ListActionBar(filter: filter, repositories: sorted, selection: $selection)
                    }
            }
        }
    }

    private func checkbox(_ id: Repository.ID) -> Binding<Bool> {
        Binding(
            get: { selection.contains(id) },
            set: { _ in selection.formSymmetricDifference([id]) }
        )
    }

    private var table: some View {
        Table(sorted, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("") { repository in
                Toggle("", isOn: checkbox(repository.id))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            .width(22)

            TableColumn(L("column.name"), value: \.name) { repository in
                NameCell(repository: repository, isBusy: store.busyIDs.contains(repository.id))
            }
            .width(min: 180, ideal: 240)

            TableColumn(L("column.status"), value: \.severityRank) { repository in
                StatusBadge(severity: repository.severity)
            }
            .width(min: 120, ideal: 140)

            TableColumn(L("column.size"), value: \.size) { repository in
                Text(Format.bytes(repository.size)).monospacedDigit()
            }
            .width(min: 70, ideal: 80)

            TableColumn(L("column.cleanable"), value: \.cleanableSize) { repository in
                Text(repository.cleanableSize > 0 ? Format.bytes(repository.cleanableSize) : "—")
                    .monospacedDigit()
                    .foregroundStyle(repository.cleanableSize > 0 ? .purple : .secondary)
            }
            .width(min: 70, ideal: 90)

            TableColumn(L("column.lastCommit"), value: \.lastCommitSort) { repository in
                Text(repository.snapshot.lastCommit.map(Format.relative) ?? L("stat.never"))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 110)
        }
        .contextMenu(forSelectionType: Repository.ID.self) { ids in
            RepositoryActionsMenu(repositories: store.repositories(for: ids))
        } primaryAction: { ids in
            store.repositories(for: ids).forEach { SystemActions.openEditor($0.url) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("empty.title"), systemImage: "externaldrive.badge.questionmark")
        } description: {
            Text(L("empty.message"))
        } actions: {
            Button(L("action.scan")) { Task { await store.scan() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct NameCell: View {
    let repository: Repository
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 10) {
            RepositoryIcon(severity: repository.severity, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(repository.name).fontWeight(.medium).lineLimit(1)
                Text(repository.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RepositoryActionsMenu: View {
    @Environment(RepositoryStore.self) private var store
    let repositories: [Repository]

    var body: some View {
        if let first = repositories.first, repositories.count == 1 {
            Button(L("action.finder")) { SystemActions.revealInFinder(first.url) }
            Button(L("action.terminal")) { SystemActions.openTerminal(first.url) }
            Button(L("action.editor")) { SystemActions.openEditor(first.url) }
            Divider()
        }
        Button(L("action.push")) { Task { await store.push(repositories) } }
        Button(L("action.backup")) { Task { await store.backup(repositories) } }
        Button(L("action.clean")) { Task { await store.clean(repositories) } }
    }
}

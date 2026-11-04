import SwiftUI

struct BulkActionsView: View {
    @Environment(RepositoryStore.self) private var store
    let repositories: [Repository]
    @State private var confirm: ConfirmableAction?

    private var totalSize: Int64 { repositories.reduce(0) { $0 + $1.size } }
    private var cleanable: Int64 { repositories.reduce(0) { $0 + $1.cleanableSize } }
    private var safe: [Repository] { repositories.filter(\.isSafeToDelete) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("bulk.title", repositories.count))
                    .font(.title2.weight(.bold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    StatTile(title: L("stat.size"), value: Format.bytes(totalSize), symbol: "internaldrive")
                    StatTile(title: L("stat.cleanable"), value: Format.bytes(cleanable), symbol: "sparkles", tint: .purple)
                    StatTile(title: L("bulk.safeCount"), value: "\(safe.count)", symbol: "checkmark.seal", tint: .green)
                }

                SectionCard(title: L("bulk.actions"), symbol: "bolt") {
                    VStack(alignment: .leading, spacing: 10) {
                        BulkButton(title: L("action.push"), symbol: "arrow.up.circle") {
                            Task { await store.push(repositories) }
                        }
                        BulkButton(title: L("action.backup"), symbol: "key") {
                            store.requestBackup(repositories)
                        }
                        BulkButton(title: L("action.clean"), symbol: "sparkles") { confirmClean() }
                            .disabled(cleanable == 0)
                        BulkButton(title: L("bulk.trashSafe", safe.count), symbol: "trash", role: .destructive) { confirmTrash() }
                            .disabled(safe.isEmpty)
                    }
                }

                SectionCard(title: L("bulk.selected"), symbol: "list.bullet") {
                    ForEach(repositories) { repository in
                        HStack {
                            RepositoryIcon(severity: repository.severity, size: 20)
                            Text(repository.name).lineLimit(1)
                            Spacer()
                            StatusBadge(severity: repository.severity)
                        }
                    }
                }
            }
            .padding(24)
        }
        .confirmation($confirm)
    }

    private func confirmClean() {
        confirm = ConfirmableAction(
            title: L("confirm.bulkClean.title", repositories.count),
            message: L("confirm.clean.message", Format.bytes(cleanable)),
            buttonTitle: L("action.clean")
        ) { Task { await store.clean(repositories) } }
    }

    private func confirmTrash() {
        confirm = ConfirmableAction(
            title: L("confirm.bulkTrash.title", safe.count),
            message: L("confirm.bulkTrash.message"),
            buttonTitle: L("action.trash")
        ) { Task { await store.trashSafe(safe) } }
    }
}

private struct BulkButton: View {
    let title: String
    let symbol: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .controlSize(.large)
    }
}

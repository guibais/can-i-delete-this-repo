import SwiftUI

struct ListActionBar: View {
    @Environment(RepositoryStore.self) private var store
    let filter: SidebarFilter
    let repositories: [Repository]
    @Binding var selection: Set<Repository.ID>
    @State private var confirm: ConfirmableAction?

    private var selected: [Repository] { repositories.filter { selection.contains($0.id) } }
    private var targets: [Repository] { selected.isEmpty ? repositories : selected }
    private var safeTargets: [Repository] { targets.filter(\.isSafeToDelete) }
    private var cleanTargets: [Repository] { targets.filter { $0.cleanableSize > 0 } }
    private var cleanSize: Int64 { cleanTargets.reduce(0) { $0 + $1.cleanableSize } }
    private var allSelected: Bool { !repositories.isEmpty && selected.count == repositories.count }

    private var selectAll: Binding<Bool> {
        Binding(
            get: { allSelected },
            set: { selection = $0 ? Set(repositories.map(\.id)) : [] }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: selectAll) {
                Text(selected.isEmpty ? L("list.selectAll") : L("list.selected", selected.count))
                    .font(.callout)
            }
            .toggleStyle(.checkbox)

            Spacer()

            if !selected.isEmpty {
                Button { Task { await store.push(selected) } } label: {
                    Label(L("action.push"), systemImage: "arrow.up.circle")
                }
                Button { store.requestBackup(selected) } label: {
                    Label(L("action.backup"), systemImage: "key")
                }
                if store.isVaultReady {
                    Button { Task { await store.restoreFromVault(selected) } } label: {
                        Label(L("vault.action.restore"), systemImage: "icloud.and.arrow.down")
                    }
                }
            }

            if filter == .cleanable || !cleanTargets.isEmpty && !selected.isEmpty {
                Button(action: confirmClean) {
                    Label(selected.isEmpty ? L("list.cleanAll") : L("action.clean"), systemImage: "sparkles")
                }
                .tint(.purple)
                .disabled(cleanTargets.isEmpty)
            }

            if filter == .safe || !safeTargets.isEmpty && !selected.isEmpty {
                Button(role: .destructive, action: confirmTrash) {
                    Label(selected.isEmpty ? L("list.removeAll") : L("action.trash"), systemImage: "trash")
                }
                .tint(.red)
                .disabled(safeTargets.isEmpty)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .confirmation($confirm)
    }

    private func confirmClean() {
        let items = cleanTargets
        confirm = ConfirmableAction(
            title: L("confirm.bulkClean.title", items.count),
            message: L("confirm.clean.message", Format.bytes(cleanSize)),
            buttonTitle: L("action.clean")
        ) { Task { await store.clean(items) } }
    }

    private func confirmTrash() {
        let items = safeTargets
        confirm = ConfirmableAction(
            title: L("confirm.bulkTrash.title", items.count),
            message: L("confirm.bulkTrash.message"),
            buttonTitle: L("action.trash")
        ) {
            selection.subtract(items.map(\.id))
            Task { await store.trashSafe(items) }
        }
    }
}

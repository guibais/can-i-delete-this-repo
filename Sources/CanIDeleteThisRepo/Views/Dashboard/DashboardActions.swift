import SwiftUI

struct QuickActionsSection: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var confirm: ConfirmableAction?

    private var secretTargets: [Repository] {
        let pending = store.repositories.filter { !$0.pendingSecrets.isEmpty }
        return pending.isEmpty ? store.repositories : pending
    }

    var body: some View {
        SectionCard(title: L("dashboard.actions"), symbol: "bolt.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                QuickActionCard(
                    title: L("dashboard.action.clean"),
                    subtitle: L("dashboard.action.clean.subtitle", Format.bytes(store.totalCleanable), store.cleanableRepositories.count),
                    symbol: "sparkles",
                    tint: .purple,
                    action: confirmClean
                )
                .disabled(store.totalCleanable == 0)

                QuickActionCard(
                    title: L("dashboard.action.trash"),
                    subtitle: L("dashboard.action.trash.subtitle", store.safeRepositories.count, Format.bytes(store.safeRepositories.reduce(0) { $0 + $1.size })),
                    symbol: "trash",
                    tint: .red,
                    action: confirmTrash
                )
                .disabled(store.safeRepositories.isEmpty)

                QuickActionCard(
                    title: L("dashboard.action.backup"),
                    subtitle: L("dashboard.action.backup.subtitle", store.pendingSecretCount),
                    symbol: "key.fill",
                    tint: .yellow
                ) { store.requestBackup(secretTargets) }

                QuickActionCard(
                    title: L("vault.title"),
                    subtitle: store.isVaultReady ? L("dashboard.action.vault.ready", store.vaultHost) : L("dashboard.action.vault.setup"),
                    symbol: "lock.shield.fill",
                    tint: .indigo
                ) { openWindow(id: VaultWindow.id) }
            }
        }
        .confirmation($confirm)
    }

    private func confirmClean() {
        let items = store.cleanableRepositories
        confirm = ConfirmableAction(
            title: L("confirm.bulkClean.title", items.count),
            message: L("confirm.clean.message", Format.bytes(store.totalCleanable)),
            buttonTitle: L("action.clean")
        ) { Task { await store.clean(items) } }
    }

    private func confirmTrash() {
        let items = store.safeRepositories
        confirm = ConfirmableAction(
            title: L("confirm.bulkTrash.title", items.count),
            message: L("confirm.bulkTrash.message"),
            buttonTitle: L("action.trash")
        ) { Task { await store.trashSafe(items) } }
    }
}

private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovering && isEnabled ? tint.opacity(0.1) : Color.secondary.opacity(0.06))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isHovering && isEnabled ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.2), value: isHovering)
    }
}

struct RecentSavingsSection: View {
    let events: [SavingsEvent]

    private static let symbols: [SavingsKind: (symbol: String, tint: Color)] = [
        .cleaned: ("sparkles", .purple),
        .trashed: ("trash.fill", .red)
    ]

    var body: some View {
        SectionCard(title: L("dashboard.recent"), symbol: "clock.arrow.circlepath") {
            if events.isEmpty {
                EmptyHint(text: L("dashboard.recent.empty"))
            }
            ForEach(events.prefix(8)) { event in
                let style = Self.symbols[event.kind] ?? ("sparkles", .purple)
                HStack(spacing: 10) {
                    Image(systemName: style.symbol)
                        .foregroundStyle(style.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.name).fontWeight(.medium)
                        Text(L("dashboard.recent.\(event.kind.rawValue)") + " · " + Format.relative(event.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+" + Format.bytes(event.bytes))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

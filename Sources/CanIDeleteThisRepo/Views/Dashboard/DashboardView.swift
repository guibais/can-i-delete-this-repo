import SwiftUI

struct DashboardView: View {
    @Environment(RepositoryStore.self) private var store
    let onSelect: (SidebarFilter) -> Void

    private var tiles: [(filter: SidebarFilter, value: String, titleKey: String)] {
        [
            (.all, "\(store.repositories.count)", "dashboard.tile.repos"),
            (.safe, "\(store.count(.safe))", "dashboard.tile.safe"),
            (.attention, "\(store.count(.attention))", "dashboard.tile.attention"),
            (.cleanable, Format.bytes(store.totalCleanable), "dashboard.tile.cleanable"),
            (.secrets, "\(store.pendingSecretCount)", "dashboard.tile.secrets"),
            (.localOnly, "\(store.count(.localOnly))", "dashboard.tile.local")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SavingsHero()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(tiles, id: \.filter) { tile in
                        Button { onSelect(tile.filter) } label: {
                            StatTile(title: L(tile.titleKey), value: tile.value, symbol: tile.filter.symbol, tint: tile.filter.tint)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { charts }
                    VStack(spacing: 16) { charts }
                }
                QuickActionsSection()
                RecentSavingsSection(events: store.savings.events)
            }
            .padding(24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .animation(.smooth, value: store.repositories.count)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("dashboard.title"))
                .font(.largeTitle.weight(.bold))
            Text(L("dashboard.subtitle", store.repositories.count, Format.bytes(store.totalSize)))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private var charts: some View {
        LargestProjectsChart(repositories: store.repositories)
            .frame(minWidth: 420)
        HealthChart(repositories: store.repositories, onSelect: onSelect)
            .frame(minWidth: 320)
    }
}

import SwiftUI

struct SidebarView: View {
    @Environment(RepositoryStore.self) private var store
    @Binding var filter: SidebarFilter?

    var body: some View {
        List(selection: $filter) {
            Label {
                Text(L(SidebarFilter.home.titleKey))
            } icon: {
                Image(systemName: SidebarFilter.home.symbol).foregroundStyle(SidebarFilter.home.tint)
            }
            .tag(SidebarFilter.home)

            Section(L("sidebar.section")) {
                ForEach(SidebarFilter.filters) { item in
                    Label {
                        Text(L(item.titleKey))
                    } icon: {
                        Image(systemName: item.symbol).foregroundStyle(item.tint)
                    }
                    .badge(store.count(item))
                    .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            StorageSummaryView()
                .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
    }
}

private struct StorageSummaryView: View {
    @Environment(RepositoryStore.self) private var store

    private var reclaimableRatio: Double {
        guard store.totalSize > 0 else { return 0 }
        return Double(store.totalCleanable) / Double(store.totalSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("summary.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if store.isScanning {
                    ProgressView().controlSize(.mini)
                }
            }

            Text(Format.bytes(store.totalSize))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())

            ProgressView(value: store.isScanning ? store.scanProgress : reclaimableRatio)
                .tint(store.isScanning ? .accentColor : .purple)

            Label(
                store.isScanning ? L("summary.scanning") : L("summary.reclaimable", Format.bytes(store.totalCleanable)),
                systemImage: store.isScanning ? "magnifyingglass" : "sparkles"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth, value: store.totalSize)
    }
}

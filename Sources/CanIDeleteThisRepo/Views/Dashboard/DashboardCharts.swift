import Charts
import SwiftUI

private struct SizeSlice: Identifiable {
    let name: String
    let kindKey: String
    let bytes: Int64

    var id: String { name + kindKey }
}

struct LargestProjectsChart: View {
    let repositories: [Repository]

    private var slices: [SizeSlice] {
        repositories.sorted { $0.size > $1.size }.prefix(7).flatMap { repository in
            [
                SizeSlice(name: repository.name, kindKey: "dashboard.chart.project", bytes: repository.size - repository.cleanableSize),
                SizeSlice(name: repository.name, kindKey: "dashboard.chart.reclaimable", bytes: repository.cleanableSize)
            ]
        }
    }

    var body: some View {
        SectionCard(title: L("dashboard.largest"), symbol: "chart.bar.xaxis") {
            if repositories.isEmpty {
                EmptyHint(text: L("dashboard.noData"))
            } else {
                Chart(slices) { slice in
                    BarMark(x: .value("Size", Double(slice.bytes)), y: .value("Project", slice.name))
                        .foregroundStyle(by: .value("Kind", L(slice.kindKey)))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale([L("dashboard.chart.project"): Color.accentColor.gradient, L("dashboard.chart.reclaimable"): Color.purple.gradient])
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel { Text(Format.bytes(Int64(value.as(Double.self) ?? 0))) }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 240)
            }
        }
    }
}

struct HealthChart: View {
    let repositories: [Repository]
    let onSelect: (SidebarFilter) -> Void

    private static let filters: [Severity: SidebarFilter] = [.safe: .safe, .warning: .attention, .danger: .all]

    private var counts: [(severity: Severity, count: Int)] {
        [Severity.safe, .warning, .danger].map { severity in
            (severity, repositories.filter { $0.severity == severity }.count)
        }
    }

    var body: some View {
        SectionCard(title: L("dashboard.health"), symbol: "heart.text.square") {
            HStack(spacing: 20) {
                Chart(counts, id: \.severity) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.64), angularInset: 2)
                        .foregroundStyle(item.severity.style.color.gradient)
                        .cornerRadius(5)
                }
                .chartBackground { _ in
                    VStack(spacing: 0) {
                        Text("\(repositories.count)")
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(L("dashboard.repos"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(counts, id: \.severity) { item in
                        Button { onSelect(Self.filters[item.severity] ?? .all) } label: {
                            HStack {
                                Circle().fill(item.severity.style.color).frame(width: 10, height: 10)
                                Text(L(item.severity.style.titleKey))
                                Spacer()
                                Text("\(item.count)")
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}

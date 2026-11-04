import Foundation

enum SidebarFilter: String, CaseIterable, Identifiable, Hashable {
    case home
    case all
    case safe
    case attention
    case localOnly
    case secrets
    case cleanable

    private static let predicates: [SidebarFilter: (Repository) -> Bool] = [
        .home: { _ in true },
        .all: { _ in true },
        .safe: { $0.severity == .safe },
        .attention: { $0.severity == .warning },
        .localOnly: { !$0.hasRemote },
        .secrets: { $0.hasSecrets },
        .cleanable: { $0.cleanableSize > 0 }
    ]

    private static let symbols: [SidebarFilter: String] = [
        .home: "house.fill",
        .all: "square.stack.3d.up.fill",
        .safe: "checkmark.seal.fill",
        .attention: "exclamationmark.triangle.fill",
        .localOnly: "externaldrive.fill.badge.xmark",
        .secrets: "key.fill",
        .cleanable: "sparkles"
    ]

    static let filters = allCases.filter { $0 != .home }

    var id: String { rawValue }
    var titleKey: String { "filter.\(rawValue)" }
    var symbol: String { Self.symbols[self] ?? "folder" }

    func matches(_ repository: Repository) -> Bool {
        Self.predicates[self]?(repository) ?? true
    }
}

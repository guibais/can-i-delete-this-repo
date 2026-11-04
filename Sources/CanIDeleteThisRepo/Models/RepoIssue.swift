import Foundation

enum IssueKind: String, CaseIterable, Hashable, Sendable {
    case noRemote
    case noCommits
    case uncommittedChanges
    case unpushedCommits
    case stashes
    case secretsNotBackedUp
    case behindRemote

    private static let severities: [IssueKind: Severity] = [
        .noRemote: .danger,
        .noCommits: .danger,
        .uncommittedChanges: .warning,
        .unpushedCommits: .warning,
        .stashes: .warning,
        .secretsNotBackedUp: .warning,
        .behindRemote: .safe
    ]

    private static let symbols: [IssueKind: String] = [
        .noRemote: "icloud.slash",
        .noCommits: "circle.dashed",
        .uncommittedChanges: "pencil.and.list.clipboard",
        .unpushedCommits: "arrow.up.circle",
        .stashes: "tray.full",
        .secretsNotBackedUp: "key.horizontal",
        .behindRemote: "arrow.down.circle"
    ]

    var severity: Severity { Self.severities[self] ?? .warning }
    var symbol: String { Self.symbols[self] ?? "questionmark.circle" }
    var titleKey: String { "issue.\(rawValue).title" }
    var detailKey: String { "issue.\(rawValue).detail" }
}

struct RepoIssue: Hashable, Sendable, Identifiable {
    let kind: IssueKind
    let count: Int

    var id: IssueKind { kind }
}

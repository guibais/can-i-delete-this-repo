import Foundation

struct Activity: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let symbol: String
    var detail = ""
    var total = 0
    var completed = 0
    var goal: Int64?
    var freed: Int64?
    var outcome: Toast?

    var isFinished: Bool { outcome != nil }
    var counter: String? { total > 1 ? "\(min(completed, total))/\(total)" : nil }

    var progress: Double? {
        if isFinished { return 1 }
        if let goal, goal > 0, let freed { return min(Double(freed) / Double(goal), 1) }
        guard total > 0 else { return nil }
        return min(Double(completed) / Double(total), 1)
    }
}

enum BackupDestination: String, Codable, CaseIterable, Sendable {
    case vault
    case folder
}

enum BackupOrigin: Sendable {
    case main
    case vault
}

struct BackupRequest: Identifiable {
    let id = UUID()
    let repositories: [Repository]
    let origin: BackupOrigin

    var fileCount: Int { repositories.reduce(0) { $0 + $1.sensitiveFiles.count } }
}

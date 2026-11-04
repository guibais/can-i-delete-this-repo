import Foundation

struct GitRemote: Hashable, Sendable, Identifiable {
    let name: String
    let url: String

    var id: String { name }

    var host: String {
        webURL?.host ?? url
    }

    var webURL: URL? {
        let trimmed = url.hasSuffix(".git") ? String(url.dropLast(4)) : url
        if trimmed.hasPrefix("http") { return URL(string: trimmed) }
        let withoutScheme = trimmed.replacingOccurrences(of: "ssh://", with: "")
        guard let address = withoutScheme.split(separator: "@").last else { return nil }
        return URL(string: "https://" + address.replacingOccurrences(of: ":", with: "/"))
    }
}

struct GitSnapshot: Hashable, Sendable {
    var branch: String?
    var remotes: [GitRemote] = []
    var changes = 0
    var unpushed = 0
    var behind = 0
    var stashes = 0
    var hasCommits = false
    var lastCommit: Date?
    var ignored: [String] = []
}

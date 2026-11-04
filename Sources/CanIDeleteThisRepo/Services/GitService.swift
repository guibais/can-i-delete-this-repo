import Foundation

enum GitService {
    static let executable: String = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
        .first(where: FileManager.default.isExecutableFile) ?? "/usr/bin/git"

    static func git(_ arguments: [String], at url: URL) async -> CommandResult {
        await Shell.run(executable, arguments, in: url)
    }

    static func snapshot(at url: URL) async -> GitSnapshot {
        async let status = git(["status", "--porcelain=v1", "-b"], at: url)
        async let remotes = git(["remote", "-v"], at: url)
        async let stashes = git(["stash", "list"], at: url)
        async let lastCommit = git(["log", "-1", "--format=%ct"], at: url)
        async let ignored = git(["ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z"], at: url)

        let parsedRemotes = parseRemotes(await remotes.output)
        let unpushed = await git(unpushedArguments(hasRemote: !parsedRemotes.isEmpty), at: url)
        let statusLines = lines(await status.output)
        let header = statusLines.first ?? ""
        let last = await lastCommit
        let stashOutput = await stashes.output
        let ignoredOutput = await ignored.output

        return GitSnapshot(
            branch: parseBranch(header),
            remotes: parsedRemotes,
            changes: max(statusLines.count - 1, 0),
            unpushed: Int(unpushed.trimmedOutput) ?? 0,
            behind: parseBehind(header),
            stashes: lines(stashOutput).count,
            hasCommits: last.succeeded && !last.trimmedOutput.isEmpty,
            lastCommit: TimeInterval(last.trimmedOutput).map(Date.init(timeIntervalSince1970:)),
            ignored: ignoredOutput.split(separator: "\0").map(String.init)
        )
    }

    static func fetch(at url: URL) async -> CommandResult {
        await git(["fetch", "--all", "--prune"], at: url)
    }

    static func push(at url: URL) async -> CommandResult {
        let upstream = await git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], at: url)
        if upstream.succeeded { return await git(["push"], at: url) }
        return await git(["push", "-u", await primaryRemote(at: url), "HEAD"], at: url)
    }

    static func pushAll(at url: URL) async -> CommandResult {
        await git(["push", "--all", "-u", await primaryRemote(at: url)], at: url)
    }

    static func commitAndPush(at url: URL, message: String) async -> CommandResult {
        let add = await git(["add", "-A"], at: url)
        guard add.succeeded else { return add }
        let commit = await git(["commit", "-m", message], at: url)
        guard commit.succeeded else { return commit }
        return await push(at: url)
    }

    static func parseBranch(_ header: String) -> String? {
        let body = header.replacingOccurrences(of: "## ", with: "")
        let noCommitsPrefix = "No commits yet on "
        if body.hasPrefix(noCommitsPrefix) { return String(body.dropFirst(noCommitsPrefix.count)) }
        if body.hasPrefix("HEAD (no branch)") || body.isEmpty { return nil }
        return body.components(separatedBy: "...").first?.components(separatedBy: " ").first
    }

    static func parseBehind(_ header: String) -> Int {
        guard let tail = header.components(separatedBy: "behind ").dropFirst().first else { return 0 }
        return Int(tail.prefix(while: \.isNumber)) ?? 0
    }

    static func parseRemotes(_ output: String) -> [GitRemote] {
        lines(output)
            .filter { $0.hasSuffix("(fetch)") }
            .compactMap { line in
                let parts = line.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 2 else { return nil }
                return GitRemote(name: String(parts[0]), url: String(parts[1]))
            }
    }

    private static func unpushedArguments(hasRemote: Bool) -> [String] {
        let base = ["rev-list", "--count", "--branches"]
        return hasRemote ? base + ["--not", "--remotes"] : base
    }

    private static func primaryRemote(at url: URL) async -> String {
        let remotes = parseRemotes(await git(["remote", "-v"], at: url).output)
        return remotes.first(where: { $0.name == "origin" })?.name ?? remotes.first?.name ?? "origin"
    }

    private static func lines(_ output: String) -> [String] {
        output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}

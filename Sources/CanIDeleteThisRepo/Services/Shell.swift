import Foundation

struct CommandResult: Sendable {
    let status: Int32
    let output: String
    let error: String

    var succeeded: Bool { status == 0 }
    var trimmedOutput: String { output.trimmingCharacters(in: .whitespacesAndNewlines) }

    var message: String {
        let trimmedError = error.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedError.isEmpty ? trimmedOutput : trimmedError
    }

    static let success = CommandResult(status: 0, output: "", error: "")

    static func failure(_ message: String) -> CommandResult {
        CommandResult(status: 1, output: "", error: message)
    }
}

enum Shell {
    static func run(_ executable: String, _ arguments: [String], in directory: URL? = nil) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runSync(executable, arguments, in: directory))
            }
        }
    }

    private static func runSync(_ executable: String, _ arguments: [String], in directory: URL?) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return .failure(error.localizedDescription)
        }

        let errorReader = DataReader(handle: errorPipe.fileHandleForReading)
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorReader.wait()
        process.waitUntilExit()

        return CommandResult(
            status: process.terminationStatus,
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self)
        )
    }

    private static let environment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["LC_ALL"] = "C"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        return env
    }()
}

private final class DataReader: @unchecked Sendable {
    private var data = Data()
    private let group = DispatchGroup()

    init(handle: FileHandle) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            data = handle.readDataToEndOfFile()
            group.leave()
        }
    }

    func wait() -> Data {
        group.wait()
        return data
    }
}

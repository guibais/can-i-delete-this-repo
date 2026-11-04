import Foundation

enum FileOperations {
    static func remove(_ urls: [URL]) async -> CommandResult {
        await perform { try urls.forEach { try FileManager.default.removeItem(at: $0) } }
    }

    static func trash(_ url: URL) async -> CommandResult {
        await perform { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
    }

    static func removeProgressively(_ url: URL) -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    let fileManager = FileManager.default
                    let children = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                    for (index, child) in children.enumerated() {
                        try Task.checkCancellation()
                        try fileManager.removeItem(at: child)
                        continuation.yield(Double(index + 1) / Double(children.count + 1))
                    }
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                    continuation.yield(1)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func perform(_ operation: @escaping @Sendable () throws -> Void) async -> CommandResult {
        await Task.detached(priority: .userInitiated) {
            do {
                try operation()
                return CommandResult.success
            } catch {
                return CommandResult.failure(error.localizedDescription)
            }
        }.value
    }
}

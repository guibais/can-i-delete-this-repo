import Foundation

enum FileOperations {
    static func remove(_ urls: [URL]) async -> CommandResult {
        await perform { try urls.forEach { try FileManager.default.removeItem(at: $0) } }
    }

    static func trash(_ url: URL) async -> CommandResult {
        await perform { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
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

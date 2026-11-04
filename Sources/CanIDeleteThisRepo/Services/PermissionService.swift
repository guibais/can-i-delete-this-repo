import AppKit

enum PermissionStatus: Sendable {
    case unknown
    case granted
    case denied
}

enum ProtectedFolder: String, CaseIterable, Identifiable, Sendable {
    case desktop = "Desktop"
    case documents = "Documents"
    case downloads = "Downloads"

    private static let symbols: [ProtectedFolder: String] = [
        .desktop: "menubar.dock.rectangle",
        .documents: "doc.text",
        .downloads: "arrow.down.circle"
    ]

    var id: String { rawValue }
    var symbol: String { Self.symbols[self] ?? "folder" }
    var titleKey: String { "onboarding.folder.\(rawValue)" }
    var url: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(rawValue, isDirectory: true) }
    var requestedKey: String { "permission.requested.\(rawValue)" }
}

enum PermissionService {
    private static let fullDiskProbe = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")

    private static let settingsURLs: [String: String] = [
        "fullDisk": "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        "files": "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
    ]

    static var hasFullDiskAccess: Bool {
        FileManager.default.isReadableFile(atPath: fullDiskProbe.path) && (try? Data(contentsOf: fullDiskProbe, options: .alwaysMapped)) != nil
    }

    static func status(of folder: ProtectedFolder) -> PermissionStatus {
        if hasFullDiskAccess { return .granted }
        guard UserDefaults.standard.bool(forKey: folder.requestedKey) else { return .unknown }
        return canRead(folder.url) ? .granted : .denied
    }

    static func request(_ folder: ProtectedFolder) async -> PermissionStatus {
        UserDefaults.standard.set(true, forKey: folder.requestedKey)
        let url = folder.url
        let granted = await Task.detached(priority: .userInitiated) { canRead(url) }.value
        return granted ? .granted : .denied
    }

    static func openFullDiskSettings() {
        open("fullDisk")
    }

    static func openFilesSettings() {
        open("files")
    }

    static func gitVersion() async -> String? {
        let result = await Shell.run(GitService.executable, ["--version"])
        return result.succeeded ? result.trimmedOutput : nil
    }

    static func installCommandLineTools() async {
        _ = await Shell.run("/usr/bin/xcode-select", ["--install"])
    }

    private static func canRead(_ url: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil
    }

    private static func open(_ key: String) {
        guard let string = settingsURLs[key], let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

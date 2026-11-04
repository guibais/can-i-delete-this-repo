import AppKit

@MainActor
enum SystemActions {
    private static let terminals = ["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.apple.Terminal"]
    private static let editors = ["com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "dev.zed.Zed", "com.apple.dt.Xcode"]

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openTerminal(_ url: URL) {
        open(url, preferring: terminals)
    }

    static func openEditor(_ url: URL) {
        open(url, preferring: editors)
    }

    static func openWeb(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func chooseFolder(prompt: String, startingAt directory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = prompt
        panel.directoryURL = directory
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func open(_ url: URL, preferring bundleIDs: [String]) {
        let workspace = NSWorkspace.shared
        guard let app = bundleIDs.lazy.compactMap(workspace.urlForApplication(withBundleIdentifier:)).first else {
            workspace.open(url)
            return
        }
        workspace.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}

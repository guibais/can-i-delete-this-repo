import Foundation

enum FilePatterns {
    static let cleanableDirectories: Set<String> = [
        "node_modules", "bower_components", ".next", ".nuxt", ".output", ".svelte-kit", ".angular",
        ".turbo", ".parcel-cache", ".cache", ".expo", ".vercel", "dist", "build", "out", "coverage",
        "target", "Pods", "DerivedData", ".build", ".gradle", "venv", ".venv", "__pycache__",
        ".pytest_cache", ".mypy_cache", ".tox", ".dart_tool", "vendor", "tmp",
        "Library", "Temp", "Logs", "obj", "bin"
    ]

    static let secretNames: Set<String> = [
        ".npmrc", ".pypirc", ".netrc", ".dev.vars", "credentials.json", "secrets.json", "secrets.yml",
        "secrets.yaml", "master.key", "auth.json", "service-account.json", "GoogleService-Info.plist",
        "google-services.json", "local.properties", "key.properties", "id_rsa", "id_ed25519"
    ]

    static let secretExtensions: Set<String> = [
        "env", "pem", "key", "p8", "p12", "pfx", "jks", "keystore", "mobileprovision", "cer", "crt", "tfvars"
    ]

    static func isCleanable(_ entry: String) -> Bool {
        entry.hasSuffix("/") && cleanableDirectories.contains(lastComponent(entry))
    }

    static func isSensitive(_ entry: String) -> Bool {
        guard !entry.hasSuffix("/") else { return false }
        let name = lastComponent(entry)
        let fileExtension = (name as NSString).pathExtension.lowercased()
        return name.hasPrefix(".env") || secretNames.contains(name) || secretExtensions.contains(fileExtension)
    }

    private static func lastComponent(_ entry: String) -> String {
        entry.split(separator: "/").last.map(String.init) ?? entry
    }
}

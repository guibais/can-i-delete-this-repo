import Foundation

enum Localization {
    static let bundle: Bundle = {
        let bundleName = "CanIDeleteThisRepo_CanIDeleteThisRepo.bundle"
        if let url = Bundle.main.resourceURL?.appendingPathComponent(bundleName), let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    static let languageKey = "app.language"
    static let systemLanguage = "system"
    static let supported = [systemLanguage, "en", "pt-BR"]

    static func apply(_ language: String) {
        if language == systemLanguage {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            return
        }
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
    }
}

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: Localization.bundle, comment: "")
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: .current, arguments: arguments)
}

enum Format {
    private static let relativeFormatter = RelativeDateTimeFormatter()
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: .now)
    }
}

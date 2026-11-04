import SwiftUI

struct SeverityStyle {
    let titleKey: String
    let bannerKey: String
    let symbol: String
    let color: Color
}

extension Severity {
    private static let styles: [Severity: SeverityStyle] = [
        .safe: SeverityStyle(titleKey: "status.safe", bannerKey: "banner.safe", symbol: "checkmark.seal.fill", color: .green),
        .warning: SeverityStyle(titleKey: "status.attention", bannerKey: "banner.warning", symbol: "exclamationmark.triangle.fill", color: .orange),
        .danger: SeverityStyle(titleKey: "status.risk", bannerKey: "banner.danger", symbol: "xmark.octagon.fill", color: .red)
    ]

    var style: SeverityStyle { Self.styles[self] ?? Self.styles[.warning]! }
}

extension SidebarFilter {
    private static let tints: [SidebarFilter: Color] = [
        .home: .indigo,
        .all: .accentColor,
        .safe: .green,
        .attention: .orange,
        .localOnly: .red,
        .secrets: .yellow,
        .cleanable: .purple
    ]

    var tint: Color { Self.tints[self] ?? .accentColor }
}

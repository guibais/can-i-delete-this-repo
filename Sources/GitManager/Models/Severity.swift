import Foundation

enum Severity: Int, Comparable, Hashable, Sendable {
    case safe
    case warning
    case danger

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

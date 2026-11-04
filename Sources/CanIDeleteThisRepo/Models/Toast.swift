import Foundation

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool

    static func success(_ message: String) -> Toast { Toast(message: message, isError: false) }
    static func failure(_ message: String) -> Toast { Toast(message: message, isError: true) }
}

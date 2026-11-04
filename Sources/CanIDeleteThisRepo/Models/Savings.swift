import Foundation

enum SavingsKind: String, Codable, Sendable {
    case cleaned
    case trashed
}

struct SavingsEvent: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    let name: String
    let bytes: Int64
    let kind: SavingsKind
    let date: Date
}

struct SavingsLedger: Codable, Sendable {
    private(set) var totalFreed: Int64 = 0
    private(set) var counts: [SavingsKind: Int] = [:]
    private(set) var events: [SavingsEvent] = []

    private static let storageKey = "app.savings"
    private static let eventLimit = 40

    func count(_ kind: SavingsKind) -> Int { counts[kind] ?? 0 }

    mutating func add(_ bytes: Int64) {
        totalFreed += max(bytes, 0)
    }

    mutating func log(_ name: String, bytes: Int64, kind: SavingsKind) {
        counts[kind, default: 0] += 1
        events.insert(SavingsEvent(name: name, bytes: bytes, kind: kind, date: .now), at: 0)
        events = Array(events.prefix(Self.eventLimit))
        save()
    }

    static func load() -> SavingsLedger {
        DemoData.isEnabled ? DemoData.savings : Persistence.load(SavingsLedger.self, key: storageKey) ?? SavingsLedger()
    }

    func save() {
        guard !DemoData.isEnabled else { return }
        Persistence.save(self, key: Self.storageKey)
    }
}

enum Persistence {
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

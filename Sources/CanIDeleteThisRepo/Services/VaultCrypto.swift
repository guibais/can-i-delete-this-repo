import CryptoKit
import Foundation
import Security

enum VaultCrypto {
    private static let service = "io.github.guibais.canideletethisrepo.vault"
    private static let account = "vault-key"
    private static let magic = Data("CDR1".utf8)
    private static let syncedKey = "vault.keySynced"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static var isKeySynced: Bool { UserDefaults.standard.bool(forKey: syncedKey) }

    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func loadKey() -> SymmetricKey? {
        var query = baseQuery
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    static func saveKey(_ key: SymmetricKey) {
        var deleteQuery = baseQuery
        deleteQuery[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(deleteQuery as CFDictionary)

        let data = key.withUnsafeBytes { Data($0) }
        let synced = add(data, synchronizable: true) == errSecSuccess
        UserDefaults.standard.set(synced, forKey: syncedKey)
        guard !synced else { return }
        _ = add(data, synchronizable: false)
    }

    static func deleteKey() {
        var query = baseQuery
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(query as CFDictionary)
    }

    static func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else { throw VaultError.invalidData }
        return magic + combined
    }

    static func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        guard data.starts(with: magic) else { throw VaultError.invalidData }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(magic.count))
        return try AES.GCM.open(box, using: key)
    }

    static func recoveryKey(for key: SymmetricKey) -> String {
        let hex = key.withUnsafeBytes { Data($0) }.map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 8)
            .map { offset in
                let start = hex.index(hex.startIndex, offsetBy: offset)
                return String(hex[start..<hex.index(start, offsetBy: 8)])
            }
            .joined(separator: "-")
    }

    static func key(fromRecovery text: String) -> SymmetricKey? {
        let hex = Array(text.uppercased().filter(\.isHexDigit))
        guard hex.count == 64 else { return nil }
        let bytes = stride(from: 0, to: hex.count, by: 2).compactMap { UInt8(String(hex[$0...$0 + 1]), radix: 16) }
        return bytes.count == 32 ? SymmetricKey(data: Data(bytes)) : nil
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func add(_ data: Data, synchronizable: Bool) -> OSStatus {
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrSynchronizable as String] = synchronizable ? kCFBooleanTrue : kCFBooleanFalse
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrLabel as String] = "Can I Delete This Repo Vault Key"
        return SecItemAdd(query as CFDictionary, nil)
    }
}

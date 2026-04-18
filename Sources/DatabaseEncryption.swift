import Foundation
import CryptoKit

enum MessageEncryptionError: Error, LocalizedError {
    case unavailable
    case invalidTextEncoding
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Encrypted local storage is unavailable right now. Check macOS Keychain access and try again."
        case .invalidTextEncoding:
            return "Failed to encode text for encrypted local storage."
        case .encryptionFailed:
            return "Failed to encrypt local data."
        }
    }
}

final class MessageEncryption {
    static let shared = MessageEncryption()

    private var _key: SymmetricKey?
    private let initializationError: Error?
    private static let keychainAccount = "db-encryption-key-v1"
    private static let stringPrefix = "enc1:"
    private static let dataPrefix = Data("encd1:".utf8)

    private var key: SymmetricKey? {
        if let k = _key { return k }
        // Keychain may have been unavailable at init — retry lazily
        let keychain = KeychainService()
        guard let stored = try? keychain.read(account: Self.keychainAccount),
              let data = Data(base64Encoded: stored),
              data.count == 32 else { return nil }
        _key = SymmetricKey(data: data)
        return _key
    }

    private init() {
        let keychain = KeychainService()
        do {
            if let stored = try keychain.read(account: Self.keychainAccount),
               let data = Data(base64Encoded: stored),
               data.count == 32 {
                _key = SymmetricKey(data: data)
                initializationError = nil
                return
            }

            let fresh = SymmetricKey(size: .bits256)
            let keyData = fresh.withUnsafeBytes { Data($0) }
            try keychain.save(keyData.base64EncodedString(), for: Self.keychainAccount)
            _key = fresh
            initializationError = nil
        } catch {
            _key = nil
            initializationError = error
        }
    }

    func isEncryptedString(_ value: String) -> Bool {
        value.hasPrefix(Self.stringPrefix)
    }

    func isEncryptedData(_ value: Data) -> Bool {
        value.starts(with: Self.dataPrefix)
    }

    func encryptString(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        guard let key else { throw initializationError ?? MessageEncryptionError.unavailable }
        guard let data = plaintext.data(using: .utf8) else {
            throw MessageEncryptionError.invalidTextEncoding
        }

        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw MessageEncryptionError.encryptionFailed
        }
        return Self.stringPrefix + combined.base64EncodedString()
    }

    func decryptString(_ stored: String) -> String {
        guard stored.hasPrefix(Self.stringPrefix) else { return stored }
        let b64 = String(stored.dropFirst(Self.stringPrefix.count))
        guard let combined = Data(base64Encoded: b64),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let key,
              let plainData = try? AES.GCM.open(box, using: key),
              let plaintext = String(data: plainData, encoding: .utf8) else {
            return stored
        }
        return plaintext
    }

    func encryptData(_ plaintext: Data) throws -> Data {
        guard !plaintext.isEmpty else { return plaintext }
        guard let key else { throw initializationError ?? MessageEncryptionError.unavailable }

        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw MessageEncryptionError.encryptionFailed
        }

        var encrypted = Self.dataPrefix
        encrypted.append(Data(combined.base64EncodedString().utf8))
        return encrypted
    }

    func decryptData(_ stored: Data) -> Data {
        guard stored.starts(with: Self.dataPrefix) else { return stored }
        let encoded = Data(stored.dropFirst(Self.dataPrefix.count))
        guard let combined = Data(base64Encoded: encoded),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let key,
              let plaintext = try? AES.GCM.open(box, using: key) else {
            return stored
        }
        return plaintext
    }
}

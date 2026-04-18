import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            "Keychain error with status \(status)"
        case .invalidData:
            "Invalid data returned from Keychain"
        }
    }
}

struct KeychainService {
    private var currentService: String {
        Bundle.main.bundleIdentifier ?? "com.sehford.valeurayai.macosapp"
    }

    private var fallbackServices: [String] {
        [
            "com.valienteclifford.UnifiedAIChat",
            "com.valienteclifford.ValeurAI"
        ]
    }

    private var knownServices: [String] {
        [currentService] + fallbackServices.filter { $0 != currentService }
    }

    func save(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: currentService,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(account: String) throws -> String? {
        for service in knownServices {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound {
                continue
            }
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
            guard
                let data = item as? Data,
                let value = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.invalidData
            }
            return value
        }

        return nil
    }

    func delete(account: String) throws {
        for service in knownServices {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }
}

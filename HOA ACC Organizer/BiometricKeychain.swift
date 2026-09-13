// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import LocalAuthentication
import Security

/// Describes Keychain and biometric credential-storage failures.
enum BiometricKeychainError: Error, LocalizedError {
    case accessControl
    case save(OSStatus)
    case read(OSStatus)
    case invalidData

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .accessControl:
            return "Unable to configure biometric protection."
        case .save(let status):
            return "Unable to save biometric login (\(status))."
        case .read(let status):
            return "Unable to read biometric login (\(status))."
        case .invalidData:
            return "The stored biometric login is invalid."
        }
    }
}

/// Stores the account identity required to unlock biometric login on a device.
struct BiometricKeychain {
    /// The Keychain service identifier used for biometric account storage.
    private static let service =
        "org.smoketree.HOAACCOrganizer.admin"
    /// The count represented by account.
    private static let account =
        "biometric-admin"

    /// Saves the authenticated account identifier behind biometric access control.
    static func saveUserID(
        _ userID: String
    ) throws {
        delete()

        var error: Unmanaged<CFError>?

        guard let access =
            SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                [.biometryCurrentSet],
                &error
            )
        else {
            throw BiometricKeychainError.accessControl
        }

        let data = Data(userID.utf8)

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account,
            kSecAttrAccessControl as String:
                access,
            kSecValueData as String:
                data
        ]

        let status =
            SecItemAdd(
                query as CFDictionary,
                nil
            )

        guard status == errSecSuccess else {
            throw BiometricKeychainError.save(status)
        }
    }

    /// Reads the biometric account identifier after successful device authentication.
    static func readUserID(
        context: LAContext
    ) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account,
            kSecReturnData as String:
                true,
            kSecMatchLimit as String:
                kSecMatchLimitOne,
            kSecUseAuthenticationContext as String:
                context
        ]

        var item: CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &item
            )

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw BiometricKeychainError.read(status)
        }

        guard
            let data = item as? Data,
            let value = String(
                data: data,
                encoding: .utf8
            )
        else {
            throw BiometricKeychainError.invalidData
        }

        return value
    }

    /// Backward-compatible administrator save API.
    static func saveAdminID(
        _ userID: String
    ) throws {
        try saveUserID(
            userID
        )
    }

    /// Backward-compatible administrator read API.
    static func readAdminID(
        context: LAContext
    ) throws -> String? {
        try readUserID(
            context: context
        )
    }

    /// Deletes delete for `BiometricKeychain`.
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )
    }
}

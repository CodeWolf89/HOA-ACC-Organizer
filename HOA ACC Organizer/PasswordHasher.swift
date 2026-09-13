// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import CommonCrypto
import Security

/// Describes failures while generating a PBKDF2 password verifier.
enum PasswordHashError: Error, LocalizedError {
    case randomSaltFailed
    case derivationFailed

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .randomSaltFailed:
            return "Unable to generate a secure password salt."
        case .derivationFailed:
            return "Unable to derive a password verifier."
        }
    }
}

/// Creates and verifies salted PBKDF2-HMAC-SHA256 administrator password verifiers.
struct PasswordHasher {
    /// The default PBKDF2 iteration count used when deriving persisted password verifiers.
    static let defaultIterations: UInt32 = 210_000

    /// The number of random bytes generated for each PBKDF2 salt.
    private static let saltLength = 16
    /// The number of derived-key bytes stored for password verification.
    private static let keyLength = 32

    /// Creates a salted PBKDF2 verifier suitable for persistent password validation.
    static func makeVerifier(
        password: String
    ) throws -> (
        hash: String,
        salt: String,
        iterations: Int
    ) {
        var salt = Data(count: saltLength)

        let randomStatus =
            salt.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(
                    kSecRandomDefault,
                    saltLength,
                    buffer.baseAddress!
                )
            }

        guard randomStatus ==
                errSecSuccess
        else {
            throw PasswordHashError.randomSaltFailed
        }

        let derived =
            try derive(
                password: password,
                salt: salt,
                iterations:
                    defaultIterations
            )

        return (
            derived.base64EncodedString(),
            salt.base64EncodedString(),
            Int(defaultIterations)
        )
    }

    /// Verifies  and returns whether validation succeeds.
    static func verify(
        password: String,
        expectedHash: String,
        salt: String,
        iterations: Int
    ) -> Bool {
        guard
            let expected =
                Data(
                    base64Encoded:
                        expectedHash
                ),
            let saltData =
                Data(
                    base64Encoded:
                        salt
                ),
            iterations > 0 &&
                iterations <=
                    Int(UInt32.max)
        else {
            return false
        }

        guard let derived =
            try? derive(
                password: password,
                salt: saltData,
                iterations:
                    UInt32(iterations)
            )
        else {
            return false
        }

        return constantTimeEqual(
            derived,
            expected
        )
    }

    /// Derives PBKDF2-HMAC-SHA256 key material from the supplied password, salt, and iteration count.
    private static func derive(
        password: String,
        salt: Data,
        iterations: UInt32
    ) throws -> Data {
        var output =
            Data(count: keyLength)

        let result: Int32 =
            password.withCString {
                passwordPointer in

                output.withUnsafeMutableBytes {
                    outputBuffer in

                    salt.withUnsafeBytes {
                        saltBuffer in

                        CCKeyDerivationPBKDF(
                            CCPBKDFAlgorithm(
                                kCCPBKDF2
                            ),
                            passwordPointer,
                            password.utf8.count,
                            saltBuffer
                                .bindMemory(
                                    to: UInt8.self
                                )
                                .baseAddress,
                            salt.count,
                            CCPseudoRandomAlgorithm(
                                kCCPRFHmacAlgSHA256
                            ),
                            iterations,
                            outputBuffer
                                .bindMemory(
                                    to: UInt8.self
                                )
                                .baseAddress,
                            keyLength
                        )
                    }
                }
            }

        guard result ==
                kCCSuccess
        else {
            throw PasswordHashError.derivationFailed
        }

        return output
    }

    /// Compares verifier bytes without early exit to reduce timing differences.
    private static func constantTimeEqual(
        _ lhs: Data,
        _ rhs: Data
    ) -> Bool {
        guard lhs.count ==
                rhs.count
        else {
            return false
        }

        var difference:
            UInt8 = 0

        for index in
            0..<lhs.count {
            difference |=
                lhs[index] ^
                rhs[index]
        }

        return difference == 0
    }
}

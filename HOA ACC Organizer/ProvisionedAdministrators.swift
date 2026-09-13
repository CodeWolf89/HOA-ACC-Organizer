// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import CryptoKit

/// Describes one application account that is provisioned at build time.
///
/// Plaintext passwords are never stored in the application. `loginSHA256` is
/// used to validate the distributed password before the local PBKDF2 verifier
/// is repaired into SQLite.
struct ProvisionedAccountCredential: Hashable {
    /// The account username associated with this value.
    let username: String
    /// The human-readable name displayed for this value.
    let displayName: String
    /// The authorization role assigned to this account.
    let role: String

    // PBKDF2 verifier persisted into SQLite after a successful login.
    /// The salted PBKDF2 password verifier persisted for this account.
    let passwordHash: String
    /// The random salt used to derive the persisted PBKDF2 verifier.
    let passwordSalt: String
    /// The PBKDF2 iteration count used to derive the password verifier.
    let iterations: Int

    // Provisioned-login verifier. No plaintext password is stored.
    /// The build-provisioned SHA-256 verifier used for first-factor credential validation.
    let loginSHA256: String

    /// Returns whether this credential grants administrator privileges.
    var isAdministrator: Bool {
        role.caseInsensitiveCompare(
            "admin"
        ) == .orderedSame
    }
}

/// Backward-compatible name retained for older call sites and documentation.
typealias ProvisionedAdministratorCredential =
    ProvisionedAccountCredential

/// Defines the application accounts distributed with the app.
///
/// Roles are intentionally explicit:
/// - `admin` unlocks editing, adjudication, backup, and audit features.
/// - `user` authenticates a standard account without administrator privileges.
enum ProvisionedAccounts {
    /// The count represented by accounts.
    static let accounts: [ProvisionedAccountCredential] = [
        ProvisionedAccountCredential(
            username: "SHOA_ACC_SuperUser",
            displayName: "SHOA ACC SuperUser",
            role: "admin",
            passwordHash: "49OIY9fIAsqKh7RcatRD3fpSDifGdu3DGzYoCdlVl6c=",
            passwordSalt: "QIDbdH7bHTvlmpzMDsk2og==",
            iterations: 210000,
            loginSHA256: "206ed584bec5a99ace42825954b3da9944ad363da83c0bd90638aa688e7be216"
        ),
        ProvisionedAccountCredential(
            username: "SHOA_ACC_Lead",
            displayName: "SHOA ACC Lead",
            role: "admin",
            passwordHash: "4UySPWO/Ff34A/B/RixVv0hCuC5UA4MwJOdRfkB++fY=",
            passwordSalt: "wFQyMwlOAc03IhHir0o3Lw==",
            iterations: 210000,
            loginSHA256: "0fb7f0e1ece21402c1b2900d5e64cafd477e210dcd0345ead12d67e85c8ddd96"
        ),
        ProvisionedAccountCredential(
            username: "SHOA_BOD_Member",
            displayName: "SHOA BOD Member",
            role: "admin",
            passwordHash: "f+oBw8Qe7fxOoQflX1kXVlF/bnnIYMTGspYsYs+sO08=",
            passwordSalt: "RgRLd5aH4whH6MMZG8TnOw==",
            iterations: 210000,
            loginSHA256: "6e48935ee64e962001d1c064eb263dbc3a5186f88785dab563fb412e8d444eb6"
        ),
        ProvisionedAccountCredential(
            username: "SHOA_BOD_Volunteer",
            displayName: "SHOA BOD Volunteer",
            role: "user",
            passwordHash: "8e/8FtROtLmhNowigoZYSLNQbtexEWqkS1Zx1NUc85M=",
            passwordSalt: "xGlxzYs3OICCf7RmKSKkjg==",
            iterations: 210000,
            loginSHA256: "acc6e14a9596804e366c8ba67f76575b990ad2941072fbb3273048373b479517"
        ),
        ProvisionedAccountCredential(
            username: "Apple_ReviewAccount",
            displayName: "Apple Review Account",
            role: "admin",
            passwordHash: "BNNekqI0tvI5X9JokOpOz1C7p0+lxpDlaEUYElhPXBk=",
            passwordSalt: "JfbZH9d2b+Sbwt8lbDzwHQ==",
            iterations: 210000,
            loginSHA256: "2d76624844b30a59c045f8f1408c887abc2da787db64677b38176a394eaba0d9"
        )
    ]

    /// Finds a provisioned credential using case-insensitive username matching.
    static func credential(
        username: String
    ) -> ProvisionedAccountCredential? {
        let normalized =
            normalizedUsername(
                username
            )

        return accounts.first {
            normalizedUsername(
                $0.username
            ) == normalized
        }
    }

    /// Authenticates a provisioned account without storing the plaintext password.
    static func authenticate(
        username: String,
        password: String
    ) -> ProvisionedAccountCredential? {
        guard
            let credential =
                credential(
                    username: username
                )
        else {
            return nil
        }

        for candidate in
            passwordCandidates(
                password
            ) {
            if sha256(candidate) ==
                credential.loginSHA256 {
                return credential
            }
        }

        return nil
    }

    /// Generates a lowercase SHA-256 hexadecimal verifier.
    private static func sha256(
        _ value: String
    ) -> String {
        let digest =
            SHA256.hash(
                data: Data(value.utf8)
            )

        return digest.map {
            String(
                format: "%02x",
                $0
            )
        }
        .joined()
    }

    /// Normalizes usernames for stable case-insensitive comparison.
    private static func normalizedUsername(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "en_US_POSIX"
                    )
            )
    }

    /// Produces safe password variants for common keyboard/paste dash substitutions.
    private static func passwordCandidates(
        _ value: String
    ) -> [String] {
        let cleaned =
            value
                .replacingOccurrences(
                    of: "\u{200B}",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\u{FEFF}",
                    with: ""
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .precomposedStringWithCanonicalMapping

        var candidates: [String] = [
            cleaned
        ]

        let dashCharacters =
            CharacterSet(
                charactersIn:
                    "-‐‑‒–—−"
            )

        let canonicalASCII =
            String(
                String.UnicodeScalarView(
                    cleaned.unicodeScalars.map {
                        dashCharacters
                            .contains($0)
                        ? UnicodeScalar(45)!
                        : $0
                    }
                )
            )

        candidates.append(
            canonicalASCII
        )

        let baseCharacters =
            Array(canonicalASCII)

        let dashIndexes =
            baseCharacters.indices.filter {
                baseCharacters[$0] == "-"
            }

        for index in dashIndexes {
            for replacement in
                ["—", "–", "‑"] {
                var copy =
                    baseCharacters

                copy[index] =
                    Character(
                        replacement
                    )

                candidates.append(
                    String(copy)
                )
            }
        }

        var seen = Set<String>()

        return candidates.filter {
            seen.insert($0).inserted
        }
    }
}

/// Backward-compatible alias retained while older source files transition to
/// the more accurate `ProvisionedAccounts` name.
typealias ProvisionedAdministrators =
    ProvisionedAccounts

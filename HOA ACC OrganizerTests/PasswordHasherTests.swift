// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Represents password hasher tests within HOA ACC Organizer.
struct PasswordHasherTests {
    /// Performs the generated verifier accepts correct password and rejects wrong password operation used by `PasswordHasherTests`.
    @Test
    func generatedVerifierAcceptsCorrectPasswordAndRejectsWrongPassword() throws {
        let verifier = try PasswordHasher.makeVerifier(password: "Example-Password-123")

        #expect(
            PasswordHasher.verify(
                password: "Example-Password-123",
                expectedHash: verifier.hash,
                salt: verifier.salt,
                iterations: verifier.iterations
            )
        )

        #expect(
            PasswordHasher.verify(
                password: "wrong-password",
                expectedHash: verifier.hash,
                salt: verifier.salt,
                iterations: verifier.iterations
            ) == false
        )
    }

    /// Performs the malformed verifier fails closed operation used by `PasswordHasherTests`.
    @Test
    func malformedVerifierFailsClosed() {
        #expect(
            PasswordHasher.verify(
                password: "anything",
                expectedHash: "not-base64",
                salt: "also-not-base64",
                iterations: 1
            ) == false
        )
    }
}

// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Represents provisioned administrator tests within HOA ACC Organizer.
struct ProvisionedAdministratorTests {
    /// Performs the expected provisioned accounts are present without plaintext passwords operation used by `ProvisionedAdministratorTests`.
    @Test
    func expectedProvisionedAccountsArePresentWithoutPlaintextPasswords() throws {
        #expect(
            ProvisionedAccounts.accounts.count ==
                5
        )

        let superUser =
            try #require(
                ProvisionedAccounts
                    .credential(
                        username:
                            " shoa_acc_superuser "
                    )
            )

        #expect(
            superUser.username ==
                "SHOA_ACC_SuperUser"
        )
        #expect(
            superUser.isAdministrator
        )
        #expect(
            !superUser.passwordHash.isEmpty
        )
        #expect(
            !superUser.passwordSalt.isEmpty
        )
        #expect(
            superUser.iterations >=
                100_000
        )
        #expect(
            superUser.loginSHA256.count ==
                64
        )
    }

    /// Performs the volunteer account is standard user operation used by `ProvisionedAdministratorTests`.
    @Test
    func volunteerAccountIsStandardUser() throws {
        let volunteer =
            try #require(
                ProvisionedAccounts
                    .credential(
                        username:
                            "SHOA_BOD_Volunteer"
                    )
            )

        #expect(
            volunteer.role == "user"
        )
        #expect(
            volunteer.isAdministrator ==
                false
        )
        #expect(
            volunteer.loginSHA256.count ==
                64
        )
    }

    /// Performs the apple review account is administrator operation used by `ProvisionedAdministratorTests`.
    @Test
    func appleReviewAccountIsAdministrator() throws {
        let reviewAccount =
            try #require(
                ProvisionedAccounts
                    .credential(
                        username:
                            "Apple_ReviewAccount"
                    )
            )

        #expect(
            reviewAccount.isAdministrator
        )
        #expect(
            reviewAccount.loginSHA256.count ==
                64
        )
        #expect(
            !reviewAccount.passwordHash.isEmpty
        )
    }

    /// Performs the unknown provisioned username fails closed operation used by `ProvisionedAdministratorTests`.
    @Test
    func unknownProvisionedUsernameFailsClosed() {
        #expect(
            ProvisionedAccounts
                .credential(
                    username:
                        "not-a-real-account"
                ) == nil
        )
    }
}

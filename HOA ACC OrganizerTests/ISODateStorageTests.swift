// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents iso date storage tests within HOA ACC Organizer.
struct ISODateStorageTests {
    /// Performs the date round trip uses iso8601 operation used by `ISODateStorageTests`.
    @Test
    func dateRoundTripUsesISO8601()
        throws {
        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.timeZone =
            TimeZone(
                secondsFromGMT: 0
            )!

        let date =
            try #require(
                calendar.date(
                    from:
                        DateComponents(
                            year: 2026,
                            month: 9,
                            day: 12,
                            hour: 15,
                            minute: 30
                        )
                )
            )

        let stored =
            ISODateStorage.string(
                from: date
            )

        #expect(
            stored ==
                "2026-09-12T15:30:00Z"
        )

        #expect(
            ISODateStorage.date(
                from: stored
            ) ==
                date
        )
    }

    /// Performs the optional date serializes to nil operation used by `ISODateStorageTests`.
    @Test
    func optionalDateSerializesToNil() {
        let date: Date? = nil

        #expect(
            ISODateStorage.optionalString(
                from: date
            ) == nil
        )
    }

    /// Performs the legacy date canonicalizes to iso8601 operation used by `ISODateStorageTests`.
    @Test
    func legacyDateCanonicalizesToISO8601() {
        let value =
            ISODateStorage.canonical(
                "09/12/2026"
            )

        #expect(value != nil)
        #expect(
            value?.contains("T")
                == true
        )
        #expect(
            value?.hasSuffix("Z")
                == true
        )
    }

    /// Performs the written out date can be parsed operation used by `ISODateStorageTests`.
    @Test
    func writtenOutDateCanBeParsed() {
        #expect(
            ISODateStorage.date(
                from:
                    "September 12, 2026"
            ) != nil
        )
    }
}

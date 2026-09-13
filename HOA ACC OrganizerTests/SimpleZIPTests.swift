// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents simple zip tests within HOA ACC Organizer.
struct SimpleZIPTests {
    /// Performs the archive round trip preserves names and bytes operation used by `SimpleZIPTests`.
    @Test
    func archiveRoundTripPreservesNamesAndBytes() throws {
        let entries = [
            SimpleZIP.Entry(name: "manifest.json", data: Data("{}".utf8)),
            SimpleZIP.Entry(name: "Attachments/photo.jpg", data: Data([0, 1, 2, 3, 255]))
        ]

        let archive = try SimpleZIP.create(entries: entries)
        let extracted = try SimpleZIP.extract(data: archive)

        #expect(extracted["manifest.json"] == Data("{}".utf8))
        #expect(extracted["Attachments/photo.jpg"] == Data([0, 1, 2, 3, 255]))
    }

    /// Performs the malformed archive is rejected operation used by `SimpleZIPTests`.
    @Test
    func malformedArchiveIsRejected() {
        #expect(throws: SimpleZIPError.self) {
            _ = try SimpleZIP.extract(data: Data("not a zip".utf8))
        }
    }

    /// Performs the path traversal entry is rejected operation used by `SimpleZIPTests`.
    @Test
    func pathTraversalEntryIsRejected() throws {
        let archive = try SimpleZIP.create(
            entries: [.init(name: "../outside.txt", data: Data("x".utf8))]
        )

        #expect(throws: SimpleZIPError.self) {
            _ = try SimpleZIP.extract(data: archive)
        }
    }
}

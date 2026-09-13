// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Represents acc on device parser fallback tests within HOA ACC Organizer.
struct ACCOnDeviceParserFallbackTests {
    /// Performs the new draft defaults to vision fallback message operation used by `ACCOnDeviceParserFallbackTests`.
    @Test
    func newDraftDefaultsToVisionFallbackMessage() {
        let draft = ACCApplicationDraft(
            lotID: "lot-test"
        )

        #expect(draft.ocrUsedOnDeviceModel == false)
        #expect(
            draft.ocrAssistanceMessage
                .contains("Vision OCR")
        )
    }
}

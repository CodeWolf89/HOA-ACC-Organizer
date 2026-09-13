// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import UniformTypeIdentifiers

/// Wraps generated JSON data for SwiftUI file export.
struct JSONExportDocument: FileDocument {
    /// The Uniform Type Identifiers this document type can read.
    static var readableContentTypes: [UTType] {
        [.json]
    }

    /// The binary or encoded data used for data.
    let data: Data

    /// Creates an instance with the supplied dependencies and initial values.
    init(data: Data = Data()) {
        self.data = data
    }

    /// Creates an instance with the supplied dependencies and initial values.
    init(configuration: ReadConfiguration) throws {
        self.data =
            configuration.file.regularFileContents
            ?? Data()
    }

    /// Creates the file wrapper used by SwiftUI document export.
    func fileWrapper(
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: data
        )
    }
}

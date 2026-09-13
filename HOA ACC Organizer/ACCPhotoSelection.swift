// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import UniformTypeIdentifiers

/// Represents a homeowner-supplied ACC photo selected before it is persisted as an attachment.
struct ACCPendingPhoto: Identifiable {
    /// The stable identifier for this value.
    let id = UUID()
    /// The original filename supplied by the user or source application.
    let originalFileName: String
    /// The MIME type describing the attachment contents.
    let mimeType: String
    /// The filename extension selected for this pending ACC photo.
    let fileExtension: String
    /// The binary or encoded data used for data.
    let data: Data

    /// The count represented by byte count text.
    var byteCountText: String {
        ByteCountFormatter.string(
            fromByteCount:
                Int64(data.count),
            countStyle: .file
        )
    }

    /// Loads  from its configured source.
    static func load(
        from url: URL
    ) throws -> ACCPendingPhoto {
        let scoped =
            url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data =
            try Data(
                contentsOf: url,
                options: .mappedIfSafe
            )

        guard
            data.count <=
                50 * 1024 * 1024
        else {
            throw ACCPhotoSelectionError
                .fileTooLarge(
                    url.lastPathComponent
                )
        }

        let type =
            UTType(
                filenameExtension:
                    url.pathExtension
            )
            ?? .image

        let mimeType =
            type.preferredMIMEType
            ?? "image/jpeg"

        let fileExtension =
            type.preferredFilenameExtension
            ?? (
                url.pathExtension.isEmpty
                ? "jpg"
                : url.pathExtension
            )

        return ACCPendingPhoto(
            originalFileName:
                url.lastPathComponent,
            mimeType:
                mimeType,
            fileExtension:
                fileExtension,
            data:
                data
        )
    }
}

/// Describes validation failures while selecting homeowner-supplied ACC photos.
enum ACCPhotoSelectionError:
    Error,
    LocalizedError {

    case fileTooLarge(String)

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let name):
            return
                "\(name) is larger than the 50 MB per-photo limit."
        }
    }
}

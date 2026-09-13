// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Describes unsupported or malformed backup ZIP archives.
enum SimpleZIPError: Error, LocalizedError {
    case archiveTooLarge
    case invalidArchive
    case unsupportedCompression

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .archiveTooLarge:
            return "The backup archive is too large for the current ZIP writer."
        case .invalidArchive:
            return "The selected backup archive is invalid."
        case .unsupportedCompression:
            return "The backup uses an unsupported ZIP compression method."
        }
    }
}

/// Implements the small uncompressed ZIP subset used for self-contained HOA ACC backups.
struct SimpleZIP {
    /// Represents entry within HOA ACC Organizer.
    struct Entry {
        /// The human-readable name associated with this value.
        let name: String
        /// The binary or encoded data used for data.
        let data: Data
    }

    /// Creates  and returns the resulting value when applicable.
    static func create(
        entries: [Entry]
    ) throws -> Data {
        var output = Data()
        var central = Data()

        for entry in entries {
            let nameData =
                Data(entry.name.utf8)

            guard
                entry.data.count <= Int(UInt32.max),
                nameData.count <= Int(UInt16.max),
                output.count <= Int(UInt32.max)
            else {
                throw SimpleZIPError.archiveTooLarge
            }

            let crc =
                CRC32.checksum(entry.data)

            let localOffset =
                UInt32(output.count)

            output.appendLE(UInt32(0x04034b50))
            output.appendLE(UInt16(20))
            output.appendLE(UInt16(0x0800))
            output.appendLE(UInt16(0))
            output.appendLE(UInt16(0))
            output.appendLE(UInt16(0))
            output.appendLE(crc)
            output.appendLE(UInt32(entry.data.count))
            output.appendLE(UInt32(entry.data.count))
            output.appendLE(UInt16(nameData.count))
            output.appendLE(UInt16(0))
            output.append(nameData)
            output.append(entry.data)

            central.appendLE(UInt32(0x02014b50))
            central.appendLE(UInt16(20))
            central.appendLE(UInt16(20))
            central.appendLE(UInt16(0x0800))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(crc)
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt16(nameData.count))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt32(0))
            central.appendLE(localOffset)
            central.append(nameData)
        }

        guard
            entries.count <= Int(UInt16.max),
            central.count <= Int(UInt32.max),
            output.count <= Int(UInt32.max)
        else {
            throw SimpleZIPError.archiveTooLarge
        }

        let centralOffset =
            UInt32(output.count)

        output.append(central)

        output.appendLE(UInt32(0x06054b50))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(entries.count))
        output.appendLE(UInt16(entries.count))
        output.appendLE(UInt32(central.count))
        output.appendLE(centralOffset)
        output.appendLE(UInt16(0))

        return output
    }

    /// Extracts all files from a validated SimpleZIP archive into the destination directory.
    static func extract(
        data: Data
    ) throws -> [String: Data] {
        var cursor = 0
        var entries: [String: Data] = [:]

        while cursor + 4 <= data.count {
            let signature =
                try data.readUInt32LE(
                    at: cursor
                )

            if signature ==
                0x02014b50 ||
                signature ==
                0x06054b50 {
                break
            }

            guard signature ==
                    0x04034b50
            else {
                throw SimpleZIPError.invalidArchive
            }

            guard cursor + 30 <= data.count else {
                throw SimpleZIPError.invalidArchive
            }

            let flags =
                try data.readUInt16LE(
                    at: cursor + 6
                )

            let compression =
                try data.readUInt16LE(
                    at: cursor + 8
                )

            guard compression == 0 else {
                throw SimpleZIPError.unsupportedCompression
            }

            guard flags & 0x0008 == 0 else {
                throw SimpleZIPError.invalidArchive
            }

            let compressedSize =
                Int(
                    try data.readUInt32LE(
                        at: cursor + 18
                    )
                )

            let nameLength =
                Int(
                    try data.readUInt16LE(
                        at: cursor + 26
                    )
                )

            let extraLength =
                Int(
                    try data.readUInt16LE(
                        at: cursor + 28
                    )
                )

            let nameStart =
                cursor + 30

            let nameEnd =
                nameStart + nameLength

            let dataStart =
                nameEnd + extraLength

            let dataEnd =
                dataStart + compressedSize

            guard
                nameEnd <= data.count,
                dataEnd <= data.count
            else {
                throw SimpleZIPError.invalidArchive
            }

            let nameData =
                data.subdata(
                    in: nameStart..<nameEnd
                )

            guard
                let name = String(
                    data: nameData,
                    encoding: .utf8
                ),
                !name.contains(".."),
                !name.hasPrefix("/")
            else {
                throw SimpleZIPError.invalidArchive
            }

            entries[name] =
                data.subdata(
                    in: dataStart..<dataEnd
                )

            cursor = dataEnd
        }

        return entries
    }
}

/// Defines the supported crc32 values used by the application.
private enum CRC32 {
    /// The precomputed CRC-32 lookup table used by ZIP checksum calculations.
    private static let table: [UInt32] = {
        (0..<256).map { index in
            var value = UInt32(index)

            for _ in 0..<8 {
                if value & 1 == 1 {
                    value =
                        0xEDB88320 ^
                        (value >> 1)
                } else {
                    value >>= 1
                }
            }

            return value
        }
    }()

    /// Computes the CRC-32 checksum used by ZIP records.
    static func checksum(
        _ data: Data
    ) -> UInt32 {
        var crc: UInt32 =
            0xFFFFFFFF

        for byte in data {
            let index =
                Int(
                    (crc ^ UInt32(byte))
                    & 0xFF
                )

            crc =
                table[index] ^
                (crc >> 8)
        }

        return crc ^ 0xFFFFFFFF
    }
}

/// Adds HOA ACC Organizer behavior to `Data`.
private extension Data {
    /// Appends a little-endian integer to ZIP binary output.
    mutating func appendLE(
        _ value: UInt16
    ) {
        var little =
            value.littleEndian

        Swift.withUnsafeBytes(
            of: &little
        ) {
            append(
                contentsOf: $0
            )
        }
    }

    /// Appends a little-endian integer to ZIP binary output.
    mutating func appendLE(
        _ value: UInt32
    ) {
        var little =
            value.littleEndian

        Swift.withUnsafeBytes(
            of: &little
        ) {
            append(
                contentsOf: $0
            )
        }
    }

    /// Reads a little-endian 16-bit integer from ZIP binary data.
    func readUInt16LE(
        at offset: Int
    ) throws -> UInt16 {
        guard offset + 2 <= count else {
            throw SimpleZIPError.invalidArchive
        }

        return UInt16(self[offset]) |
            (UInt16(self[offset + 1]) << 8)
    }

    /// Reads a little-endian 32-bit integer from ZIP binary data.
    func readUInt32LE(
        at offset: Int
    ) throws -> UInt32 {
        guard offset + 4 <= count else {
            throw SimpleZIPError.invalidArchive
        }

        return UInt32(self[offset]) |
            (UInt32(self[offset + 1]) << 8) |
            (UInt32(self[offset + 2]) << 16) |
            (UInt32(self[offset + 3]) << 24)
    }
}

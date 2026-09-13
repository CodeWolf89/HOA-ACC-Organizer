// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import OSLog

/// Stores lightweight startup and sync checkpoints that help diagnose failures without exposing raw internals in release UI.
nonisolated enum RuntimeDiagnostics {
    /// The OSLog logger used for runtime diagnostic events.
    private static let logger = Logger(
        subsystem: "com.shoa.acc.HOA-ACC-Organizer",
        category: "runtime"
    )

    /// The UserDefaults key storing the most recent runtime checkpoint name.
    private static let checkpointKey =
        "hoaacc.runtime.lastCheckpoint"

    /// The UserDefaults key storing the most recent runtime checkpoint timestamp.
    private static let checkpointDateKey =
        "hoaacc.runtime.lastCheckpointDate"

    /// Records a lightweight runtime checkpoint for launch/sync diagnostics.
    static func checkpoint(
        _ value: String
    ) {
        logger.notice("Checkpoint: \(value, privacy: .public)")

        UserDefaults.standard.set(
            value,
            forKey: checkpointKey
        )

        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: checkpointDateKey
        )
    }

    /// The most recently recorded runtime checkpoint identifier.
    static var lastCheckpoint: String {
        UserDefaults.standard.string(
            forKey: checkpointKey
        ) ?? "None"
    }

    /// The date or timestamp associated with last checkpoint date.
    static var lastCheckpointDate: Date? {
        let value = UserDefaults.standard.double(
            forKey: checkpointDateKey
        )

        return value > 0
            ? Date(timeIntervalSince1970: value)
            : nil
    }

    /// A user-facing representation of the latest runtime diagnostic checkpoint.
    static var displayText: String {
        let status =
            UserFacingStatus.runtimeCheckpoint(
                lastCheckpoint
            )

        guard let date = lastCheckpointDate else {
            return status
        }

        return "\(status) • " +
            date.formatted(
                date: .omitted,
                time: .standard
            )
    }
}

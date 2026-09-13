// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Converts internal diagnostic strings into plain-language status messages.
///
/// Debug builds intentionally keep the technical text so Xcode logs and the
/// in-app status screen remain useful during development. Release builds use
/// the friendly variants below.
nonisolated enum UserFacingStatus {
    /// Converts an internal runtime checkpoint into the appropriate Debug or user-facing status string.
    static func runtimeCheckpoint(
        _ rawValue: String
    ) -> String {
        #if DEBUG
        return rawValue
        #else
        return friendlyCheckpoint(
            rawValue
        )
        #endif
    }

    /// Converts a technical nearby-sync status into language suitable for normal users.
    static func syncStatus(
        _ rawValue: String
    ) -> String {
        #if DEBUG
        return rawValue
        #else
        return friendlySyncStatus(
            rawValue
        )
        #endif
    }

    /// Converts a technical nearby-sync error into an actionable user-facing message.
    static func syncError(
        _ rawValue: String
    ) -> String {
        #if DEBUG
        return rawValue
        #else
        return friendlySyncError(
            rawValue
        )
        #endif
    }

    /// Converts a technical nearby-sync progress message into user-facing language.
    static func syncProgress(
        _ rawValue: String
    ) -> String {
        #if DEBUG
        return rawValue
        #else
        return friendlySyncProgress(
            rawValue
        )
        #endif
    }

    /// Converts the companion violation-feed state into user-facing status text.
    static func violationFeedStatus(
        _ rawValue: String
    ) -> String {
        #if DEBUG
        return rawValue
        #else
        return friendlyViolationFeedStatus(
            rawValue
        )
        #endif
    }

    // MARK: - Testable release-language mappings

    /// Converts a runtime checkpoint identifier into a concise user-facing description.
    static func friendlyCheckpoint(
        _ rawValue: String
    ) -> String {
        let value =
            rawValue
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let lower =
            value.lowercased()

        if lower.contains(
            "startup.complete"
        ) || lower == "ready" {
            return "Ready"
        }

        if lower.contains(
            "startup.database"
        ) {
            return "Opening HOA records…"
        }

        if lower.contains(
            "startup.owner"
        ) {
            return "Loading property records…"
        }

        if lower.contains(
            "startup.admin"
        ) {
            return "Preparing administrator access…"
        }

        if lower.contains(
            "startup.refresh"
        ) || lower.contains(
            "refreshing database"
        ) {
            return "Refreshing HOA records…"
        }

        if lower.contains(
            "startup.sync.state"
        ) {
            return "Checking sync history…"
        }

        if lower.contains(
            "startup.reminders"
        ) {
            return "Updating reminders…"
        }

        if lower.contains(
            "startup.network"
        ) || lower == "starting" ||
            lower.contains("network.start") {
            return "Starting nearby sync…"
        }

        if lower.contains(
            "startup.error"
        ) {
            return "Startup needs attention"
        }

        if lower.contains(
            "scene.background"
        ) || lower == "app is in background" {
            return "App paused"
        }

        if lower.contains(
            "scene.active"
        ) {
            return "App active"
        }

        if lower.contains(
            "network.listener.ready"
        ) || lower == "ready to connect" {
            return "Ready for nearby devices"
        }

        if lower.contains(
            "network.connection.ready"
        ) {
            return "Connected to a nearby device"
        }

        if lower.contains(
            "network.frame.hello"
        ) {
            return "Confirming nearby device…"
        }

        if lower.contains(
            "network.frame.snapshot"
        ) {
            return "Receiving HOA records…"
        }

        if lower.contains(
            "network.frame.requestattachments"
        ) {
            return "Checking photos and PDFs…"
        }

        if lower.contains(
            "network.frame.attachment"
        ) {
            return "Transferring photos and PDFs…"
        }

        if lower.contains(
            "network.frame.synccomplete"
        ) || lower.contains(
            "network.sync.complete"
        ) || lower == "sync complete" {
            return "Sync complete"
        }

        if lower.contains(
            "network.sync.error"
        ) || lower.contains(
            "network.frame.syncerror"
        ) || lower == "network error" ||
            lower == "malfunction 54." {
            return "Sync needs attention"
        }

        if lower.contains(
            "network.stop"
        ) || lower == "service stopped" {
            return "Nearby sync paused"
        }

        if value.isEmpty ||
            lower == "none" {
            return "Ready"
        }

        return value
    }

    /// Returns the release-build wording for a nearby-sync status.
    static func friendlySyncStatus(
        _ rawValue: String
    ) -> String {
        let value =
            rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let lower =
            value.lowercased()

        if lower.hasPrefix(
            "searching for nearby"
        ) {
            return "Looking for another HOA ACC device…"
        }

        if lower ==
            "nearby sync is available." {
            return "Ready to connect to a nearby HOA ACC device."
        }

        if lower.hasPrefix(
            "discovered:"
        ) || lower ==
            "board member discovered" {
            return "Nearby HOA ACC device found."
        }

        if lower.hasPrefix(
            "connected:"
        ) {
            let name =
                String(
                    value.dropFirst(
                        "Connected:".count
                    )
                )
                .trimmingCharacters(
                    in: .whitespaces
                )

            return name.isEmpty
                ? "Connected to a nearby HOA ACC device."
                : "Connected to \(name)."
        }

        if lower.hasPrefix(
            "no nearby hoa acc device"
        ) || lower ==
            "no board member detected nearby" {
            return "No nearby HOA ACC device is connected. Keep both apps open and try again."
        }

        if lower.contains(
            "sync is already in progress"
        ) {
            return "A sync is already in progress."
        }

        if lower.hasPrefix(
            "preparing sync with"
        ) || lower.hasPrefix(
            "preparing metadata"
        ) {
            return "Preparing HOA records for sync…"
        }

        if lower.hasPrefix(
            "sending metadata"
        ) {
            return "Sending HOA records…"
        }

        if lower.hasPrefix(
            "metadata sent"
        ) {
            return "HOA records sent. Waiting for the other device…"
        }

        if lower.hasPrefix(
            "applying data"
        ) || lower.hasPrefix(
            "applying metadata"
        ) {
            return "Updating HOA records…"
        }

        if lower.hasPrefix(
            "requesting"
        ) && lower.contains(
            "attachment"
        ) {
            return "Requesting missing photos and PDFs…"
        }

        if lower.hasPrefix(
            "sending "
        ) && lower.contains(
            " to "
        ) {
            return "Sending a photo or PDF…"
        }

        if lower.hasPrefix(
            "receiving "
        ) && lower.contains(
            " from "
        ) {
            return "Receiving a photo or PDF…"
        }

        if lower.hasPrefix(
            "sync completed with"
        ) {
            let name =
                value
                    .replacingOccurrences(
                        of: "Sync completed with ",
                        with: ""
                    )
                    .trimmingCharacters(
                        in: CharacterSet(
                            charactersIn: ". "
                        )
                    )

            return name.isEmpty
                ? "Sync complete."
                : "Up to date with \(name)."
        }

        if lower ==
            "nearby sync is not running." {
            return "Nearby sync is paused."
        }

        return value
    }

    /// Returns the release-build wording for a nearby-sync error.
    static func friendlySyncError(
        _ rawValue: String
    ) -> String {
        let lower =
            rawValue.lowercased()

        if lower.contains(
            "listener waiting"
        ) || lower.contains(
            "discovery waiting"
        ) {
            return "Nearby sync is waiting for local network access. Check the app's Local Network permission and try again."
        }

        if lower.contains(
            "listener failed"
        ) || lower.contains(
            "discovery failed"
        ) || lower.contains(
            "unable to start network"
        ) {
            return "Nearby device discovery is unavailable. Check the local network connection and try again."
        }

        if lower.contains(
            "connection failed"
        ) || lower.contains(
            "receive failed"
        ) || lower.contains(
            "send failed"
        ) {
            return "The connection to the nearby device was interrupted. Keep both apps open and try again."
        }

        if lower.contains(
            "receive-buffer safety limit"
        ) || lower.contains(
            "frame exceeded"
        ) || lower.contains(
            "too large"
        ) {
            return "This sync contains more data than the device can safely process at once. Use a full backup instead."
        }

        if lower.contains(
            "unable to apply nearby sync"
        ) {
            return "The received HOA records could not be saved. Try syncing again; if the problem continues, use a full backup."
        }

        if lower.contains(
            "attachment"
        ) || lower.contains(
            "photo"
        ) || lower.contains(
            "pdf"
        ) {
            return "Some photos or PDFs could not be transferred. Keep both apps open and try the sync again."
        }

        if lower.contains(
            "unable to record sync completion"
        ) {
            return "The data transfer finished, but the app could not update the last-sync record."
        }

        return "Nearby sync could not be completed. Try again with both devices awake and the app open."
    }

    /// Returns the release-build wording for nearby-sync progress.
    static func friendlySyncProgress(
        _ rawValue: String
    ) -> String {
        let value =
            rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let lower =
            value.lowercased()

        if lower ==
            "preparing metadata…" {
            return "Preparing HOA records…"
        }

        if lower.contains(
            "bytes of metadata"
        ) {
            return "Preparing HOA records…"
        }

        if lower ==
            "applying metadata…" {
            return "Updating HOA records…"
        }

        if lower.hasPrefix(
            "waiting for"
        ) && lower.contains(
            "attachment"
        ) {
            return value
                .replacingOccurrences(
                    of: "attachment(s)",
                    with: "photo(s) / PDF(s)"
                )
        }

        if lower.hasPrefix(
            "preparing"
        ) && lower.contains(
            "attachment"
        ) {
            return value
                .replacingOccurrences(
                    of: "attachment(s)",
                    with: "photo(s) / PDF(s)"
                )
        }

        if lower ==
            "waiting for completion acknowledgement" {
            return "Finishing sync…"
        }

        return value
    }

    /// Returns the release-build wording for companion violation-feed status.
    static func friendlyViolationFeedStatus(
        _ rawValue: String
    ) -> String {
        let lower =
            rawValue.lowercased()

        if lower.contains(
            "intake stopped"
        ) {
            return "Violation intake is paused."
        }

        if lower.contains(
            "starting violation app intake"
        ) {
            return "Starting violation intake…"
        }

        if lower.contains(
            "ready to receive"
        ) {
            return "Ready to receive violation reports."
        }

        if lower.contains(
            "receiving violation reports"
        ) {
            return "Receiving violation reports…"
        }

        if lower.contains(
            "sync received"
        ) {
            return "Violation reports received."
        }

        if lower.contains(
            "waiting"
        ) {
            return "Violation intake is waiting for a network connection."
        }

        if lower.contains(
            "failed"
        ) || lower.contains(
            "unable to start"
        ) {
            return "Violation reports could not be received. Check the local network and try again."
        }

        return rawValue
    }
}

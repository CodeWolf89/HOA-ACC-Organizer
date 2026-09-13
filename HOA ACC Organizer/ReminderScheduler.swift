// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import UserNotifications

/// Schedules local notifications for violation deadlines, ACC review timing, and stale synchronization state.
final class ReminderScheduler {
    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore
    /// The UserNotifications notification center used to request permission and schedule reminders.
    private let center = UNUserNotificationCenter.current()

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) {
        self.store = store
    }

    /// Requests authorization for `ReminderScheduler`.
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            #if DEBUG
            print("Notification permission error:", error.localizedDescription)
            #endif
        }
    }

    /// Reschedules all for `ReminderScheduler`.
    func rescheduleAll() async {
        do {
            let candidates = try store.fetchReminderCandidates()

            let identifiers = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter {
                    $0.hasPrefix("hoaacc.violation.") ||
                    $0.hasPrefix("hoaacc.acc.")
                }

            if !identifiers.isEmpty {
                center.removePendingNotificationRequests(
                    withIdentifiers: identifiers
                )
            }

            for item in candidates.violations {
                scheduleViolation(item)
            }

            for item in candidates.applications {
                scheduleApplication(item)
            }
        } catch {
            #if DEBUG
            print("Reminder scheduling error:", error.localizedDescription)
            #endif
        }
    }

    /// Schedules violation for `ReminderScheduler`.
    private func scheduleViolation(
        _ item: ViolationReminderCandidate
    ) {
        guard !isClosed(item.status) else {
            return
        }

        if let deadline = ISODateStorage.date(
            from: item.correctionDeadline
        ), let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: deadline
        ) {
            add(
                identifier: "hoaacc.violation.\(item.id).correction",
                title: "Violation correction date approaching",
                body: "Lot \(item.lotNumber) has a correction deadline tomorrow.",
                fireDate: reminderDate
            )
        }

        if let escalation = ISODateStorage.date(
            from: item.escalationDate
        ), let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: 5,
            to: escalation
        ) {
            add(
                identifier: "hoaacc.violation.\(item.id).escalation",
                title: "Escalated violation follow-up",
                body: "Lot \(item.lotNumber) reached five days after escalation.",
                fireDate: reminderDate
            )
        }
    }

    /// Schedules application for `ReminderScheduler`.
    private func scheduleApplication(
        _ item: ACCReminderCandidate
    ) {
        guard isActiveApplication(item.status),
              let imported = ISODateStorage.date(
                from: item.importedAt
              ),
              let reminderDate = Calendar.current.date(
                byAdding: .day,
                value: 2,
                to: imported
              ) else {
            return
        }

        add(
            identifier: "hoaacc.acc.\(item.id).review",
            title: "ACC application review",
            body: "Lot \(item.lotNumber) has an ACC application that was imported two days ago.",
            fireDate: reminderDate
        )
    }

    /// Adds or replaces a local notification request for the supplied reminder candidate.
    private func add(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        guard fireDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            #if DEBUG
            if let error {
                print(
                    "Unable to schedule reminder:",
                    error.localizedDescription
                )
            }
            #endif
        }
    }

    /// Reschedules sync staleness reminder for `ReminderScheduler`.
    func rescheduleSyncStalenessReminder(
        lastSuccessfulSyncAt: String?
    ) async {
        let identifier =
            "hoaacc.sync.stale"

        center.removePendingNotificationRequests(
            withIdentifiers: [
                identifier
            ]
        )

        let lastDate =
            ISODateStorage.date(
                from:
                    lastSuccessfulSyncAt
            )

        let base =
            lastDate ?? Date()

        let weeklyDate =
            Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: base
            )
            ?? Date()
                .addingTimeInterval(
                    7 * 24 * 60 * 60
                )

        let fireDate: Date

        if weeklyDate <= Date() {
            fireDate =
                Date()
                    .addingTimeInterval(
                        60 * 60
                    )
        } else {
            fireDate =
                weeklyDate
        }

        add(
            identifier: identifier,
            title:
                "HOA ACC data may be out of date",
            body:
                "It has been about a week since this device last synchronized. Open HOA ACC Organizer and sync or import the latest data.",
            fireDate: fireDate
        )
    }


    /// Returns whether a violation status represents a closed/resolved violation.
    private func isClosed(_ status: String) -> Bool {
        let value = status.lowercased()
        return value == "resolved" || value == "closed"
    }

    /// Returns whether an ACC status should still be treated as active for reminder scheduling.
    private func isActiveApplication(_ status: String) -> Bool {
        let value = status.lowercased()
        return [
            "under review",
            "pending",
            "submitted",
            "needs information"
        ].contains(value)
    }
}

<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# HOA Violations -> HOA ACC Organizer Nearby Sync

## What changed

This build adds a separate one-way local-network transfer path from HOA Violations to HOA ACC Organizer.

- HOA Violations browses for Bonjour service `_hoavfeed._tcp`.
- HOA ACC Organizer advertises `_hoavfeed._tcp` in addition to its existing `_hoaacc._tcp` Organizer-to-Organizer service.
- The Organizer's existing `_hoaacc._tcp` full-data sync code was not replaced.
- HOA Violations sends its existing `ACC-HOA-VIOLATION-BATCH` JSON representation.
- HOA ACC Organizer imports that batch through its existing ViolationImporter.
- Report UUIDs remain authoritative: new UUIDs insert; changed matching UUIDs update; unchanged matching reports are counted as duplicates.
- Photos and rules embedded in the violation batch are imported.
- Once imported, violations are part of HOA ACC Organizer's SQLite database and therefore participate in its normal Organizer-to-Organizer full-data sync.
- Violation-app intake does not update the Organizer's existing peer-sync timestamp, so its current sync cadence/staleness behavior is preserved.
- The transfer is intentionally one-way. HOA ACC Organizer does not send its richer database back to HOA Violations.

## How to test

1. Install/open the updated HOA ACC Organizer on the receiving device.
2. Install/open the updated HOA Violations on another iPhone/iPad.
3. Put both devices on the same LAN, or keep peer-to-peer Wi-Fi available.
4. Grant Local Network permission to both apps when prompted.
5. Keep HOA ACC Organizer open.
6. In HOA Violations, open Dashboard.
7. Wait until Organizer Sync says `HOA ACC Organizer found`.
8. Tap `Sync Violations to Organizer`.
9. Confirm the acknowledgement reports new/updated/unchanged counts.
10. Open the relevant lot in HOA ACC Organizer and verify rules/photos/report status.
11. If a second Organizer device exists, use the Organizer's existing `Sync Now` flow; the imported violation should propagate through the existing Organizer sync.

## Conflict behavior

The Organizer's existing ViolationImporter behavior is retained. If a matching Organizer violation already has local adjudication actions, incoming Violation-app updates do not overwrite the Organizer's locally adjudicated status/escalation/final-warning/resolution values.

## Local network privacy

HOA Violations now has an explicit Info.plist with:
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices = [_hoavfeed._tcp]`

HOA ACC Organizer declares:
- `_hoaacc._tcp` for its existing peer sync
- `_hoavfeed._tcp` for one-way Violation-app intake

Because HOA Violations now intentionally transmits violation data to a nearby Organizer at the user's request, the app's published privacy policy should be updated to mention this user-initiated local-network transfer.

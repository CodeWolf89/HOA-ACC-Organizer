<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# TestFlight Round 2 fixes

This rebuild is based on the newly uploaded full project.

## Administrator login
Provisioned credentials are now centralized in `ProvisionedAdministrators.swift`.
Login verifies a provisioned account directly against its PBKDF2 verifier, repairs
the matching database row, and then completes the normal database-backed login.

This avoids stale `users` records from older TestFlight containers preventing login.
Leading/trailing whitespace in pasted usernames/passwords is ignored.

## Full-data JSON import
`attachmentURL(fileName:)` now creates the Application Support
`HOAACCOrganizer/Attachments` directory before returning a destination URL.

This fixes fresh-device imports failing with messages such as:
`The folder "...jpg" doesn't exist.`

## Nearby networking
The actual Xcode project now emits `NSBonjourServices` as an array containing
`_hoaacc._tcp`, and incoming/outgoing network access remains enabled.

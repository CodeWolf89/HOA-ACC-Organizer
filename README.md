<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# HOA ACC Organizer

HOA ACC Organizer is a native SwiftUI application for iPhone, iPad, and macOS that helps a homeowners association manage property records, violation enforcement, Architectural Control Committee (ACC) applications, photographs/PDF attachments, reminders, audit history, backups, and nearby-device synchronization.


## Project links

- Source repository: https://github.com/CodeWolf89/HOA-ACC-Organizer
- Privacy policy: https://github.com/CodeWolf89/HOA-ACC-Organizer/blob/main/PRIVACY.md
- Support: https://github.com/CodeWolf89/HOA-ACC-Organizer/blob/main/SUPPORT.md
- License: https://github.com/CodeWolf89/HOA-ACC-Organizer/blob/main/LICENSE

## Platforms

The checked-in Xcode project currently targets iOS/iPadOS 18.6 and macOS 15.6. App Store uploads in 2026 must be built with a currently supported Xcode/SDK combination; see `APP-STORE-REVIEW.md` before release.

## Privacy model

The app is local-first. It does not include advertising or third-party analytics SDKs and does not use a developer-operated cloud backend. Nearby sync uses the local network. See `PRIVACY.md` and the bundled `PrivacyInfo.xcprivacy` manifest.

## Source license

Original project-owned software is source-available under the **PolyForm Perimeter License 1.0.1**. It may be used, changed, and distributed for permitted purposes, but may not be used to provide a product that competes with HOA ACC Organizer. The license is source-available and is not an OSI-approved open-source license. The full controlling terms are in `LICENSE`.

See `RESOURCE-RIGHTS.md` before assuming the software license applies to HOA records, governing-document text, user-supplied files, trademarks, or private datasets.

## Copyright and attribution

Copyright © 2026 Christopher Mcmahon-Sutton.  
Author: Christopher Mcmahon-Sutton.  
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.

## Building

1. Open `HOA ACC Organizer.xcodeproj` in a supported Xcode release.
2. Select the HOA ACC Organizer scheme and an iPhone, iPad, or Mac destination.
3. Confirm signing/team and bundle identifier settings for your Apple Developer account.
4. Build and run.
5. Run the unit/UI test plan before archiving.
6. Build documentation with **Product → Build Documentation** for the DocC catalog.

## Release preparation

Read these files before publishing or submitting:

- `APP-STORE-REVIEW.md`
- `APP-STORE-REVIEW-NOTES.txt`
- `GITHUB-PUBLISHING.md`
- `PRIVACY.md`
- `SECURITY.md`
- `LICENSE`
- `NOTICE.md`

The production App Review password should be entered only in App Store Connect's App Review Information. Do not publish it in this repository.

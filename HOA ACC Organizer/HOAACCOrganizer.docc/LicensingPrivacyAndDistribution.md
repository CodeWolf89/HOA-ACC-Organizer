<!--
Copyright © 2026 Christopher McMahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher McMahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Licensing, Privacy, and Distribution

Prepare HOA ACC Organizer for source publication and Apple distribution without mixing source-code licensing, App Store end-user terms, and private HOA data.

## Source license

The repository's project-owned source code is distributed under the PolyForm Perimeter License 1.0.1. The repository-root `LICENSE` is the controlling text and `NOTICE.md` carries project attribution. PolyForm Perimeter is source-available rather than OSI open source because it prohibits providing a competing product.

The source license should not be assumed to license HOA governing documents, member/property datasets, user-supplied files, trademarks, or Apple platform materials. `RESOURCE-RIGHTS.md` documents those boundaries.

## App Store end-user terms

The PolyForm repository license is separate from the App Store end-user license. Unless the project owner intentionally supplies a custom App Store EULA after legal review, the App Store can use Apple's standard EULA for installed copies while the public source remains subject to PolyForm Perimeter.

## Privacy architecture

The application is local-first. SQLite and attachments live in the app container; camera/photos are used only for user-selected evidence; Local Authentication protects biometric account restoration; Vision/Foundation Models processing is on-device; and nearby sync uses Bonjour/Network.framework instead of a developer cloud backend.

The bundled `PrivacyInfo.xcprivacy` declares no tracking or developer collection and records the app-only UserDefaults required-reason API use. `PRIVACY.md` is the public policy that should be hosted at a stable HTTPS URL for App Store Connect.

## Public repository caution

A public source repository must not accidentally publish production HOA exports, backups, photographs, owner/member data, or plaintext review credentials. The current production source also contains build-provisioned account verifier values; treat those as security-sensitive and review `GITHUB-PUBLISHING.md` before making the repository public.

## Release checklist

Before App Review, validate the public Privacy Policy URL, Support URL, review credentials, App Privacy answers, export-compliance declaration, age rating, screenshots, permission flows, privacy manifest, and content rights. `APP-STORE-REVIEW.md` contains the current checklist and `APP-STORE-REVIEW-NOTES.txt` is a review-note template.

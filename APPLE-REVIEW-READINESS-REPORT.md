<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Apple Review Readiness Report

**Prepared:** 2026-09-13

This is a technical release-readiness checklist, not legal advice and not a guarantee of App Review approval.

## Completed in the source tree

- PolyForm Perimeter License 1.0.1 is included in `LICENSE` with the project copyright Required Notice.
- `PRIVACY.md`, `NOTICE.md`, `RESOURCE-RIGHTS.md`, `SUPPORT.md`, `SECURITY.md`, and GitHub publishing guidance are included.
- Comment-capable project files carry the project copyright/license/author/ChatGPT-assistance header dated 2026-09-13.
- Non-commentable and binary formats are covered by `COPYRIGHT-MANIFEST.md` without altering strict file formats.
- `HOA-ACC-Organizer-Info.plist` contains Camera, Photos, Face ID, Local Network, and Bonjour descriptions/configuration, copyright metadata, and `ITSAppUsesNonExemptEncryption = NO`.
- `PrivacyInfo.xcprivacy` declares no tracking, no developer collection, and the app-only UserDefaults required-reason API use.
- Privacy & Legal is available in-app to logged-in and logged-out users.
- The App Review account already exists in the application; its plaintext password is intentionally absent from the repository.
- App and test Swift files pass syntax parsing in the validation environment.
- The DocC coverage audit reports 100% documentation coverage for module-level/type-member app declarations.

## Owner input still required before submission

1. Publish the privacy policy at a stable public HTTPS URL.
2. Publish a stable Support URL with a private way to request support/privacy help.
3. Decide whether the full GitHub source repository will be public or private. A private repository is recommended until production credential verifiers and real HOA/property data are reviewed or separated from public source.
4. Replace the empty `HOAPrivacyPolicyURL`, `HOASupportURL`, and (if desired) `HOASourceCodeURL` values in `HOA-ACC-Organizer-Info.plist` with final public HTTPS URLs.
5. Enter the Apple Review username/password in App Store Connect Review Information. Keep the plaintext password out of GitHub.
6. Complete App Privacy, age-rating, content-rights, pricing/availability, screenshots, app description, keywords, and other App Store Connect metadata.
7. Confirm you have distribution rights for bundled HOA governing-rule text, association branding, property datasets, and sample content.
8. Archive with the currently required Xcode/iOS SDK and inspect the archive's privacy report before upload.
9. Test a fresh install on physical iPhone/iPad, including permission-denied paths and the Apple Review login.

## Public-source security note

The source tree contains build-provisioned password verifier values and HOA property/resource data. Verifier values are not plaintext passwords, but publishing them allows offline password guessing. Before making the repository public, rotate production credentials and consider moving production credential material to a private build configuration. Also review the property resources for data you are authorized to publish.

Nearby sync is designed for trusted local networks and compatible devices. Because HOA records can contain personal/property information, peer authentication and protected transport should be considered before representing local sync as safe on untrusted networks.

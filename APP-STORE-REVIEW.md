<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Apple App Store Review Preparation

**Prepared:** 2026-09-13

This checklist is tailored to the current HOA ACC Organizer source tree. It is not a guarantee of App Review approval and is not legal advice.

## Changes already included in this project

- `PrivacyInfo.xcprivacy` declares no tracking, no developer data collection, and the `UserDefaults` required-reason API use (`CA92.1`).
- `Info.plist` contains camera, photo-library, Face ID, local-network, and Bonjour purpose/configuration entries.
- `ITSAppUsesNonExemptEncryption` is set to `NO` because the app's cryptographic use is limited to Apple-provided system cryptography/hashing/KDF functionality and does not implement proprietary encryption. Re-evaluate this if networking/security code changes.
- Privacy & Legal is accessible in the app to all users.
- The source repository contains `PRIVACY.md`, `LICENSE`, `NOTICE.md`, and support/security guidance.
- The Xcode project uses the App Sandbox on macOS and permits the local-network client/server behavior needed by nearby sync.

## App Store Connect values you still must provide

### Privacy Policy URL

Use a public HTTPS URL that opens `PRIVACY.md` without requiring a GitHub login. For example, after creating the repository:

`https://github.com/CodeWolf89/HOA-ACC-Organizer/blob/main/PRIVACY.md`

The project now uses this exact URL in `HOAPrivacyPolicyURL`.

### Support URL

Use:

`https://github.com/CodeWolf89/HOA-ACC-Organizer/blob/main/SUPPORT.md`

The support page directs non-sensitive software reports to `https://github.com/CodeWolf89/HOA-ACC-Organizer/issues` and warns users not to post private HOA/member information publicly. The project now uses this exact URL in `HOASupportURL`.

### Source Code URL

Use:

`https://github.com/CodeWolf89/HOA-ACC-Organizer`

The project now uses this exact URL in `HOASourceCodeURL`.


### App Privacy questionnaire

Based on the current source code, the app itself does not send data to a developer-operated backend or analytics/advertising service. If the shipped build remains as reviewed here, the App Privacy answer can generally be **"No, we do not collect data from this app"** because on-device-only processing is not considered collection by Apple. Re-answer the questionnaire if you add analytics, cloud storage, remote AI, crash-reporting SDKs, hosted authentication, or any developer/third-party server.

Nearby peer-to-peer/local-network sync transfers information between user-operated devices, not to the developer. Explain this accurately in the privacy policy and review notes.

### App Review account

The app includes the provisioned review username:

`Apple_ReviewAccount`

Enter its current password only in **App Store Connect → App Review Information**. Do not place the plaintext password in GitHub, screenshots, review-note attachments, or public documentation.

### Review notes

Use `APP-STORE-REVIEW-NOTES.txt` as a starting point. Explain that core data storage is local, nearby sync is optional, Apple Intelligence parsing is optional/on-device, and Vision OCR is the fallback.

### Copyright

Suggested App Store copyright field:

`2026 Christopher Mcmahon-Sutton`

### License Agreement

The PolyForm Perimeter License in this repository is the **source-code license**. Unless you have a separate legal reason to provide a custom consumer EULA, leave App Store Connect's custom License Agreement field unset so Apple's standard App Store EULA applies to installed copies. Consult counsel if you want PolyForm terms to govern App Store end-user use as well as source distribution.

### Export compliance

The project includes `ITSAppUsesNonExemptEncryption = NO`. Confirm that the final build still uses only exempt/system cryptography before relying on that declaration. If you add non-exempt cryptography, update the key and complete Apple's export-compliance workflow.

### Age rating

Complete the current App Store Connect age-rating questionnaire. Apple updated the rating system in 2026, so do not rely on an older saved questionnaire.

### Content rights

Confirm that you have the right to distribute HOA governing-document text, association branding, property datasets, and any bundled sample content. App Review may ask for authorization when an app includes third-party trademarks or copyrighted material.

## Required build tooling

As of 2026, iOS/iPadOS uploads to App Store Connect must be built with Xcode 26 or later using the iOS/iPadOS 26 SDK or later. The deployment target may be lower than the SDK version.

## Privacy and permission checks before archive

- Test the first-run Local Network permission flow.
- Test camera/photo selection on a physical device.
- Test notification authorization and reminder scheduling.
- Test Face ID/Touch ID after a successful password login.
- Confirm denial of each optional permission fails gracefully.
- Confirm `PrivacyInfo.xcprivacy` is present in the archived app's privacy report.

## Review-account workflow to test on a fresh install

1. Launch the app.
2. Open the account/login control.
3. Sign in as `Apple_ReviewAccount` using the password stored in App Store Connect.
4. Confirm administrator controls become available.
5. Create a violation without requiring an existing violation import.
6. Add an ACC application manually.
7. Import an ACC PDF if a suitable sample is available.
8. Generate a violation PDF and an ACC decision letter.
9. Open Audit History.
10. Open Privacy & Legal.
11. Verify the app remains functional if Local Network access is denied; nearby sync may be unavailable, but core local workflows should continue.

## Security item to consider before broad public distribution

The current nearby-sync design is intended for trusted local networks and compatible devices. Because HOA records can include personal/property information, consider adding explicit peer trust/authentication and transport protection before treating nearby sync as suitable for untrusted networks. Apple's review guidelines expect appropriate security measures for user information.

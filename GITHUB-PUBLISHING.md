<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# GitHub Publishing Guide

The source code can be hosted on GitHub, but decide first whether the repository will be **private** or **public**.

## Recommended sequence

1. Create the GitHub repository privately first.
2. Push the cleaned source tree from this package.
3. Configure branch protection and repository security settings.
4. Publish `PRIVACY.md`, `LICENSE`, `NOTICE.md`, and `SUPPORT.md` at stable public HTTPS URLs (either in a public repository or through GitHub Pages).
5. Put the final Privacy Policy URL and Support URL into App Store Connect.
6. Only make the full source repository public after reviewing the sensitive items below.

## Do not publish private HOA data accidentally

The current project tree contains HOA resource data such as property addresses. Development/test screenshots, exports, backups, owner imports, PDFs, photographs, and local databases may contain names, addresses, phone numbers, email addresses, violation details, or signatures. Do not commit production exports or device data.

## Provisioned account verifier values

`HOA ACC Organizer/ProvisionedAdministrators.swift` contains build-provisioned password-verifier values for the local accounts. They are not plaintext passwords, but public verifier values enable offline password guessing and should be treated as security-sensitive. If the repository will be public, rotate the production credentials and strongly consider moving provisioned credential material to a private build configuration rather than publishing the production verifier values.

The plaintext Apple Review password belongs only in App Store Connect's App Review Information.

## Generated/private files ignored by the provided `.gitignore`

The supplied `.gitignore` excludes Xcode user state, DerivedData/build output, local databases, attachment folders, common backups/exports, generated DocC archives, and common secret/config files. Review `git status` before every push.

## Suggested repository description

> Native SwiftUI HOA Architectural Control Committee organizer for iPhone, iPad, and macOS. Source-available under PolyForm Perimeter 1.0.1.

## Suggested repository topics

`swift`, `swiftui`, `ios`, `ipados`, `macos`, `sqlite`, `hoa`, `architectural-control`, `source-available`

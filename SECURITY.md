<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Security Policy

## Supported release

Security fixes should be applied to the current App Store/TestFlight release and the current development branch.

## Reporting a security issue

Do not publish credentials, HOA member data, backups, PDFs, photographs, or exploit details in a public issue. Use a private contact method listed in the App Store Support URL or repository security-contact configuration.

## Sensitive repository material

The production project currently includes build-provisioned account verifier values and HOA property/resource data. If the GitHub repository will be public, review `GITHUB-PUBLISHING.md` before pushing. A public repository should not be treated as a safe place for production credential material or private HOA datasets.

## Nearby sync

Nearby synchronization uses Bonjour and Network.framework on the local network. Treat compatible peers and the local network as trusted infrastructure. Any future change that exposes sync beyond a trusted local network should add peer authentication and transport protection appropriate to the data being transferred.

<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# TestFlight Round 5

## SuperUser
The SuperUser PBKDF2-HMAC-SHA256 verifier was regenerated from the originally
supplied password using a fresh random salt. The plaintext password is not stored
in the project.

## Local network / sync
Error -72008 is Apple's missing-required-configuration error for local-network
access. This build stops relying on generated Info.plist build settings and uses
an explicit Info.plist containing:

- NSLocalNetworkUsageDescription
- NSBonjourServices as a real array containing `_hoaacc._tcp`

The Sync screen also reads those keys from the actual installed bundle and shows
whether the local-network configuration is present.

macOS incoming and outgoing sandbox network permissions remain enabled.

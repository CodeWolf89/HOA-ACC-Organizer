<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# TestFlight login correction — Round 4

The embedded PBKDF2 verifiers for all three provisioned administrator passwords
were independently checked and match the originally supplied passwords.

The login path has been simplified:

1. The username is matched against the compiled provisioned account list.
2. The password is verified directly against the compiled PBKDF2 verifier.
3. Only after successful password verification is the SQLite user row
   repaired/created.
4. The authenticated administrator session is established without performing a
   second independent database password verification.

The login input also disables autocorrection/capitalization and tolerates common
Unicode smart-dash substitutions introduced by mobile keyboards or paste sources.

The login screen now displays the app version/build number, making it possible to
confirm which TestFlight build is actually installed.

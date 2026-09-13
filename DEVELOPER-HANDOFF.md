<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# HOA ACC Organizer Developer Handoff

Start with the DocC landing page in:

`HOA ACC Organizer/HOAACCOrganizer.docc/HOAACCOrganizer.md`

The catalog includes onboarding, architecture, persistence, authentication,
violation and ACC workflows, OCR/Foundation Models, synchronization/backup,
audit/removal, PDF/attachments, testing, release, and privacy articles.

Before handing off a source change:

1. Run `python3 tools/docc_coverage_audit.py`.
2. Run the Xcode test plan.
3. Use **Product → Build Documentation** in Xcode and review warnings/links.
4. Follow the release checklist in the DocC catalog for device-only checks.

Current source-audit result (2026-09-12):

`DocC symbol coverage: 1460/1460 (100.0%)`

All 67 Swift source/test files also pass Swift syntax parsing in the documentation
handoff environment. Xcode is still required for full Apple-framework compilation,
DocC symbol-graph generation, and execution of the iOS/macOS tests.

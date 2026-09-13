<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Swift 6 warning cleanup

This build removes the warnings shown in the Xcode Build Documentation screenshot.

- ACC OCR static helpers are explicitly `nonisolated`, so `Task.detached` can call
  them without depending on the target's MainActor default isolation.
- PeerSyncMessage and the Codable transfer value types are explicitly `nonisolated`,
  allowing their Codable conformances to be used from the peer-sync background queue.
- `AccentColor.colorset` now exists because the target selects `AccentColor` as its
  global accent-color asset.
- Developer markdown/text notes were moved out of the app target's synchronized source
  directory so DocC no longer tries to treat them as documentation catalog content.

These were warnings in the current toolchain, but the actor-isolation warnings can
become errors under stricter Swift 6 language settings.

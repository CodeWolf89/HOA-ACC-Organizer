<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Current project audit — 2026-09-12

The complete project uploaded by the user was inspected directly.

## UI-test source

The stale UI-test line shown in the prior Xcode screenshot:

```swift
let button = app.buttons["toolbar.newViolation"]
```

does **not** exist in this uploaded project.

The current test uses:

- `toolbar.newViolation` first
- visible title `New Violation` as a fallback

There is exactly **1** `HOA_ACC_OrganizerUITests.swift` source file in the project.

## Xcode project structure

The `.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` for the app, unit-test,
and UI-test directories. There is no individual stale PBX file reference pointing
to a second copy of the UI-test source.

`ContentView.swift` contains **2** `toolbar.newViolation`
identifiers: one for the iPhone toolbar and one for the iPad split-view toolbar.

## Cleanup performed in this verified archive

- removed `__MACOSX` ZIP metadata
- removed `.DS_Store`
- removed `.xcodeproj/xcuserdata`
- marked the current UI-test source with a visible R3 verification comment
- set the UI-test target to `parallelizable = NO` in the shared scheme to make
  physical-device UI testing more deterministic
- left unit tests parallelizable

## Validation

Swift files syntax-parsed: **65**

Swift parse errors: **0**

Stale exact UI-test pattern hits: **0**

If Xcode still displays the old one-line `button.waitForExistence(timeout: 10)`
test after opening this archive, the remaining source is outside this project
folder or in DerivedData rather than in the project itself.

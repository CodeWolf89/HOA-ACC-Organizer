<!--
Copyright © 2026 Christopher Mcmahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher Mcmahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# iPhone layout and navigation fix

This revision addresses compact-width issues that did not appear on iPad or macOS.

## Main navigation

iPhone now uses a dedicated `NavigationStack` instead of presenting the
`NavigationSplitView` one column at a time.

This restores:
- an always-visible search field on the main lot list
- global actions before a lot is selected
- reliable navigation from Open Issues and newly-created violations
- a compact iPhone toolbar with New Violation, Actions, and Admin/Login

iPad and macOS continue using the split-view layout.

## Compact status bar

The iPhone bottom status area is now a compact stacked status strip rather than
three wide columns. This leaves substantially more vertical room for the lot list.

## ACC OCR review

The ACC review sheet no longer applies macOS minimum window dimensions on iOS.
Those fixed dimensions were the source of the severe left/right cropping shown
on iPhone.

Editable OCR fields now keep visible labels and rounded borders even when OCR
pre-populates the value, so the user can tell what each value represents.

The form uses inline navigation titles on iPhone and interactive keyboard
dismissal. The raw-OCR sheet also uses macOS-only minimum dimensions.

## Other compact-width fixes

macOS-only minimum sizes are now correctly guarded in:
- ACC application editing
- ACC adjudication
- ACC PDF viewer
- violation photo viewer

Long action rows use responsive horizontal/vertical layouts in:
- ACC adjudication
- lot ACC application actions
- ACC decision-letter preview
- violation PDF preview

Optional date fields use `ViewThatFits` so long labels can fall back to a
vertical layout on narrow iPhone screens.

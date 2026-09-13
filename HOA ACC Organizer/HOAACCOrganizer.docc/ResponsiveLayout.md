<!--
Copyright © 2026 Christopher McMahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher McMahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# Responsive Layout

Design screens around the space SwiftUI actually provides rather than around a list of Apple model identifiers.

## Overview

The organizer supports iPhone, iPad, and macOS. A hardware model alone does not determine the width available to a view. For example, an iPad mini can run full screen, in Split View, or in a Stage Manager window. The same device may therefore need several different layouts during one session.

The project uses these signals in priority order:

1. `ViewThatFits` for action groups whose ideal width can be measured directly.
2. `horizontalSizeClass` for broad phone-versus-tablet behavior.
3. Flexible grids and full-width controls for medium-width iPad detail columns.
4. `HardwareMachineIdentifier.current` only for diagnostics and test reports, never as the primary production layout switch.

## Action layout tiers

ACC and violation detail screens use three visual tiers:

- **Wide** — a single horizontal row when every label fits without wrapping.
- **Medium** — a full-width primary action with a two-column grid for secondary actions.
- **Compact** — vertically stacked full-width actions on iPhone and similarly constrained widths.

`ViewThatFits(in: .horizontal)` chooses between the wide and medium tiers at runtime. Wide-row labels use a single line so SwiftUI falls back to the medium layout instead of compressing text one character per line.

## Why not branch on machine strings?

Machine strings such as `iPad16,2` are useful when reproducing a bug, but they do not describe:

- current orientation,
- Split View or Stage Manager width,
- Dynamic Type size,
- Display Zoom,
- accessibility settings,
- future devices that do not yet exist.

A device table therefore becomes stale quickly and still cannot guarantee a good result. Keep device identifiers in diagnostics and make layout decisions from container constraints.

## Testing

When reporting a layout issue, capture:

- the hardware identifier from `HardwareMachineIdentifier.current` when useful,
- the device family and OS version,
- orientation,
- whether the app is full screen, Split View, or Stage Manager,
- a full-window screenshot,
- the navigation path to the affected view.

Test the action-heavy screens at minimum on a compact iPhone width, an iPad mini-sized detail column, and a wide iPad or macOS window.

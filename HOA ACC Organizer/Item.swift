// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Retained as a lightweight compatibility model because the original Xcode
/// project included Item.swift. Phase One stores HOA data in SQLite instead.
struct Item: Identifiable, Hashable, Codable {
    /// The stable identifier for this value.
    var id: UUID = UUID()
    /// The ISO-8601 timestamp associated with this message or record.
    var timestamp: Date = Date()
}

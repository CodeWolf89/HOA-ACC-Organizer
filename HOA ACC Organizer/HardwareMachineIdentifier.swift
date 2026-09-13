// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Provides the Apple hardware machine identifier for diagnostics and test reports.
///
/// The organizer deliberately does **not** use the machine identifier to choose SwiftUI layouts.
/// Device-specific branching is brittle because the usable width can change with orientation,
/// Split View, Stage Manager, Dynamic Type, Display Zoom, and future hardware. Production layout
/// decisions should instead use the space SwiftUI actually offers, such as `ViewThatFits`, size
/// classes, and container geometry.
nonisolated enum HardwareMachineIdentifier {
    /// The identifier for the current physical device, or the simulated device when running in Simulator.
    static var current: String {
        #if targetEnvironment(simulator)
        if let simulatedIdentifier =
            ProcessInfo.processInfo.environment[
                "SIMULATOR_MODEL_IDENTIFIER"
            ],
            !simulatedIdentifier.isEmpty {
            return simulatedIdentifier
        }
        #endif

        var systemInformation = utsname()
        uname(&systemInformation)

        let machineMirror =
            Mirror(
                reflecting:
                    systemInformation.machine
            )

        let identifier =
            machineMirror.children.reduce(
                into: ""
            ) { result, element in
                guard
                    let value =
                        element.value as? Int8,
                    value != 0
                else {
                    return
                }

                result.append(
                    Character(
                        UnicodeScalar(
                            UInt8(value)
                        )
                    )
                )
            }

        return identifier.isEmpty
            ? "unknown"
            : identifier
    }
}

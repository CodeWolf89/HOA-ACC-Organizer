// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Checks the installed bundle for the Bonjour and local-network configuration required by nearby sync.
enum LocalNetworkConfiguration {
    /// A concise description of whether the required local-network Bonjour configuration is present.
    static var statusDescription: String {
        let usage =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "NSLocalNetworkUsageDescription"
            ) as? String

        let services =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "NSBonjourServices"
            ) as? [String]

        let hasUsage =
            !(usage ?? "").isEmpty

        let hasOrganizerService =
            services?.contains(
                "_hoaacc._tcp"
            ) == true

        let hasViolationFeedService =
            services?.contains(
                "_hoavfeed._tcp"
            ) == true

        if hasUsage &&
            hasOrganizerService &&
            hasViolationFeedService {
            #if DEBUG
            return "Network.framework Bonjour configuration present"
            #else
            return "Ready for nearby device sync"
            #endif
            
        }

        var missing: [String] = []

        if !hasUsage {
            missing.append(
                "NSLocalNetworkUsageDescription"
            )
        }

        if !hasOrganizerService {
            missing.append(
                "_hoaacc._tcp"
            )
        }

        if !hasViolationFeedService {
            missing.append(
                "_hoavfeed._tcp"
            )
        }

        #if DEBUG
        return
            "Missing: " +
            missing.joined(
                separator: ", "
            )
        #else
        return "Local network setup needs attention"
        #endif
    }
}

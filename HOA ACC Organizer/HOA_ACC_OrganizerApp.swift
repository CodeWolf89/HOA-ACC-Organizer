// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Defines the application entry point, shared application model, and scene lifecycle handling.
@main
struct HOAACCOrganizerApp: App {
    /// The observable object owned by this view for app model.
    @StateObject private var appModel = AppModel()
    /// The SwiftUI environment value used for scene phase.
    @Environment(\.scenePhase) private var scenePhase

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    await appModel.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        appModel.appDidBecomeActive()

                    case .background:
                        appModel.appDidEnterBackground()

                    case .inactive:
                        break

                    @unknown default:
                        break
                    }
                }
        }
    }
}

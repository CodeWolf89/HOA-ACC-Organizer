// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Displays nearby-sync state and controls manual and scheduled synchronization.
struct SyncCenterView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    #if os(macOS)
    /// The macOS-specific Data Sync layout.
    private var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Data Sync")
                    .font(.title2.weight(.semibold))

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    macStatusCard

                    if let error =
                        model.sync.lastSyncError {
                        GroupBox {
                            Text(error)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                                .padding(.vertical, 4)
                        } label: {
                            Label(
                                syncErrorTitle,
                                systemImage:
                                    "exclamationmark.triangle.fill"
                            )
                        }
                    }

                    macAutomaticSyncCard

                    GroupBox {
                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {
                            Button {
                                model.syncNow()
                            } label: {
                                Label(
                                    "Sync Now",
                                    systemImage:
                                        "arrow.triangle.2.circlepath"
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            Text(
                                attachmentSyncExplanation
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(.vertical, 4)
                    } label: {
                        Label(
                            "Manual Sync",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                    }
                }
                .padding(24)
                .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
            }

            Divider()

            HStack {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
            .padding(20)
        }
        .frame(
            minWidth: 720,
            idealWidth: 780,
            minHeight: 600,
            idealHeight: 660
        )
    }

    /// The macOS status card summarizing the latest sync and network state.
    private var macStatusCard: some View {
        GroupBox {
            VStack(spacing: 0) {
                MacStatusRow(
                    title:
                        "Last successful sync",
                    value:
                        lastSyncText,
                    valueColor:
                        lastSyncColor
                )

                statusDivider

                if !model.syncState
                    .lastSyncMethod
                    .isEmpty {
                    #if DEBUG
                    MacStatusRow(
                        title: "Method",
                        value:
                            model.syncState.lastSyncMethod
                    )
                    #else
                    MacStatusRow(
                        title: "Method",
                        value:
                            "Network"
                    )
                    #endif
                    

                    statusDivider
                }

                if !model.syncState
                    .lastPeerName
                    .isEmpty {
                    MacStatusRow(
                        title: "Last device",
                        value:
                            model.syncState
                                .lastPeerName
                    )

                    statusDivider
                }

                MacStatusRow(
                    title: connectionStatusTitle,
                    value:
                        model.sync
                            .syncStatus
                )

                ViolationFeedMacStatus(
                    receiver: model.violationFeedReceiver
                )

                if !model.sync
                    .syncProgress
                    .isEmpty {
                    statusDivider

                    MacStatusRow(
                        title: "Progress",
                        value:
                            model.sync
                                .syncProgress
                    )
                }

                statusDivider

                MacStatusRow(
                    title:
                        localNetworkStatusTitle,
                    value:
                        LocalNetworkConfiguration
                            .statusDescription
                )

                statusDivider

                MacStatusRow(
                    title:
                        runtimeStatusTitle,
                    value:
                        RuntimeDiagnostics
                            .displayText
                )
            }
        } label: {
            Label(
                "Status",
                systemImage:
                    "network"
            )
        }
    }

    /// The macOS card containing automatic-sync controls and cadence selection.
    private var macAutomaticSyncCard: some View {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack {
                    Toggle(
                        "Enable automatic sync",
                        isOn:
                            automaticSyncBinding
                    )

                    Spacer()

                    Picker(
                        "Cadence",
                        selection:
                            cadenceBinding
                    ) {
                        ForEach(
                            SyncCadence.allCases
                        ) { cadence in
                            Text(
                                cadence.displayName
                            )
                            .tag(cadence)
                        }
                    }
                    .frame(width: 180)
                }

                Divider()

                Text(
                    "Automatic sync is attempted when another HOA ACC device is discovered on the local network while this app is running. iOS does not guarantee that local-network discovery will continue while the app is suspended."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                Text(
                    "Discovery uses both the normal LAN and Apple peer-to-peer Wi-Fi. On iPhone/iPad, Local Network access must be enabled for HOA ACC Organizer in Settings. On macOS, allow incoming connections for the app if the firewall prompts."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .padding(.vertical, 4)
        } label: {
            Label(
                "Automatic Local-Network Sync",
                systemImage:
                    "clock.arrow.trianglehead.counterclockwise.rotate.90"
            )
        }
    }

    /// The shared divider used between rows in the macOS sync-status card.
    private var statusDivider: some View {
        Divider()
            .padding(.leading, 176)
    }
    #endif

    #if os(iOS)
    /// The iPhone/iPad-specific Data Sync layout.
    private var iOSBody: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    LabeledContent(
                        "Last successful sync"
                    ) {
                        Text(
                            lastSyncText
                        )
                        .foregroundStyle(
                            lastSyncColor
                        )
                    }

                    if !model.syncState
                        .lastSyncMethod
                        .isEmpty {
                        LabeledContent(
                            "Method",
                            value:
                                model.syncState
                                    .lastSyncMethod
                        )
                    }

                    if !model.syncState
                        .lastPeerName
                        .isEmpty {
                        LabeledContent(
                            "Last device",
                            value:
                                model.syncState
                                    .lastPeerName
                        )
                    }

                    LabeledContent(
                        connectionStatusTitle,
                        value:
                            model.sync
                                .syncStatus
                    )

                    ViolationFeedIOSStatus(
                        receiver: model.violationFeedReceiver
                    )

                    if !model.sync
                        .syncProgress
                        .isEmpty {
                        LabeledContent(
                            "Progress",
                            value:
                                model.sync
                                    .syncProgress
                        )
                    }

                    LabeledContent(
                        localNetworkStatusTitle,
                        value:
                            LocalNetworkConfiguration
                                .statusDescription
                    )

                    LabeledContent(
                        runtimeStatusTitle,
                        value:
                            RuntimeDiagnostics
                                .displayText
                    )
                }

                if let error =
                    model.sync.lastSyncError {
                    Section(syncErrorTitle) {
                        Text(error)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                Section(
                    "Automatic Local-Network Sync"
                ) {
                    Toggle(
                        "Enable automatic sync",
                        isOn:
                            automaticSyncBinding
                    )

                    Picker(
                        "Cadence",
                        selection:
                            cadenceBinding
                    ) {
                        ForEach(
                            SyncCadence.allCases
                        ) { cadence in
                            Text(
                                cadence.displayName
                            )
                            .tag(cadence)
                        }
                    }

                    Text(
                        "Automatic sync is attempted when another HOA ACC device is discovered on the local network while this app is running. iOS does not guarantee that local-network discovery will continue while the app is suspended."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        "Discovery uses both the normal LAN and Apple peer-to-peer Wi-Fi. On iPhone/iPad, Local Network access must be enabled for HOA ACC Organizer in Settings. On macOS, allow incoming connections for the app if the firewall prompts."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        model.syncNow()
                    } label: {
                        Label(
                            "Sync Now",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                    }

                    Text(
                        attachmentSyncExplanation
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Data Sync")
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    #endif

    /// The user-facing heading for nearby connection status.
    private var connectionStatusTitle: String {
        #if DEBUG
        return "Nearby"
        #else
        return "Nearby device"
        #endif
    }

    /// The user-facing heading describing local-network configuration.
    private var localNetworkStatusTitle: String {
        #if DEBUG
        return "Local-network config"
        #else
        return "Local network"
        #endif
    }

    /// The user-facing heading for runtime diagnostic status.
    private var runtimeStatusTitle: String {
        #if DEBUG
        return "Runtime checkpoint"
        #else
        return "App status"
        #endif
    }

    /// The error information associated with sync error title.
    private var syncErrorTitle: String {
        #if DEBUG
        return "Sync Error"
        #else
        return "Sync needs attention"
        #endif
    }

    /// The explanatory text describing attachment synchronization behavior.
    private var attachmentSyncExplanation: String {
        #if DEBUG
        return "Network.framework transfers attachments separately by content hash, so photos and PDFs already on this device are not sent again."
        #else
        return "Photos and PDFs are only sent when the other device does not already have them."
        #endif
    }

    /// A binding that reads and updates the automatic-sync preference.
    private var automaticSyncBinding:
        Binding<Bool> {
        Binding(
            get: {
                model
                    .automaticSyncEnabled
            },
            set: {
                model
                    .setAutomaticSyncEnabled(
                        $0
                    )
            }
        )
    }

    /// A two-way binding between the cadence picker and the persisted sync setting.
    private var cadenceBinding:
        Binding<SyncCadence> {
        Binding(
            get: {
                model.syncCadence
            },
            set: {
                model
                    .setSyncCadence(
                        $0
                    )
            }
        )
    }

    /// The formatted last-successful-sync text displayed to the user.
    private var lastSyncText: String {
        guard
            let value =
                model.syncState
                    .lastSuccessfulSyncAt,
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return "Never"
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    /// The semantic color used to emphasize stale or missing sync state.
    private var lastSyncColor: Color {
        guard
            let value =
                model.syncState
                    .lastSuccessfulSyncAt,
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return .red
        }

        let days =
            Date()
                .timeIntervalSince(date)
            / (24 * 60 * 60)

        if days >= 14 {
            return .red
        }

        if days >= 7 {
            return .orange
        }

        return .primary
    }
}

/// Represents violation feed ios status within HOA ACC Organizer.
private struct ViolationFeedIOSStatus: View {
    /// The companion violation-feed receiver managed by this application model.
    @ObservedObject var receiver: ViolationFeedReceiverService

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        Group {
            LabeledContent(
                "Violation App intake",
                value: receiver.displayStatus
            )

            if let summary = receiver.displayLastImportSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if os(macOS)
/// Represents violation feed mac status within HOA ACC Organizer.
private struct ViolationFeedMacStatus: View {
    /// The companion violation-feed receiver managed by this application model.
    @ObservedObject var receiver: ViolationFeedReceiverService

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        VStack(spacing: 0) {
            MacStatusRow(
                title: "Violation App intake",
                value: receiver.displayStatus
            )

            if let summary = receiver.displayLastImportSummary {
                Divider()
                    .padding(.leading, 176)

                MacStatusRow(
                    title: "Last violation intake",
                    value: summary
                )
            }
        }
    }
}
#endif

#if os(macOS)
/// Represents mac status row within HOA ACC Organizer.
private struct MacStatusRow: View {
    /// The human-readable title displayed for this value.
    let title: String
    /// The value displayed by this reusable status/summary row.
    let value: String
    /// The optional foreground color applied to the displayed value.
    var valueColor: Color = .primary

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        HStack(
            alignment: .top,
            spacing: 16
        ) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(
                    width: 160,
                    alignment: .trailing
                )

            Text(value)
                .foregroundStyle(
                    valueColor
                )
                .textSelection(.enabled)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding(.vertical, 8)
    }
}
#endif

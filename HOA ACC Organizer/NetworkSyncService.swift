// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Combine
import CryptoKit
import Network

#if os(iOS)
import UIKit
#endif

/// Represents network sync frame header within HOA ACC Organizer.
nonisolated private struct NetworkSyncFrameHeader: Codable {
    /// Defines the supported kind values used by the application.
    nonisolated enum Kind: String, Codable {
        case hello
        case snapshot
        case requestAttachments
        case attachmentStart
        case attachmentChunk
        case attachmentEnd
        case attachmentsFinished
        case syncComplete
        case syncError
    }

    /// The attachment or message kind used to interpret this value.
    let kind: Kind
    /// The number of bytes in the framed network payload.
    let payloadLength: Int
    /// The content hash used for attachment deduplication and synchronization.
    let contentHash: String?
}

/// Represents network sync hello within HOA ACC Organizer.
nonisolated private struct NetworkSyncHello: Codable {
    /// The stable identifier used to distinguish this installation during synchronization.
    let deviceID: String
    /// The human-readable name displayed for this value.
    let displayName: String
    /// The Bonjour service instance name used for nearby discovery.
    let serviceName: String
}

/// Represents network attachment start within HOA ACC Organizer.
nonisolated private struct NetworkAttachmentStart: Codable {
    /// The content hash used for attachment deduplication and synchronization.
    let contentHash: String
    /// The app-managed filename used to store this attachment.
    let fileName: String
    /// The count represented by byte count.
    let byteCount: Int64
}

/// Discovers nearby Organizer installations with Bonjour and transfers structured records and attachments over Network.framework.
final class NetworkSyncService: ObservableObject {
    /// Defines the supported sync phase values used by the application.
    private enum SyncPhase {
        case idle
        case sendingSnapshot
        case receivingSnapshot
        case waitingForAttachmentRequest
        case sendingAttachments
        case receivingAttachments
        case waitingForCompletion

        /// Indicates whether is busy.
        var isBusy: Bool {
            self != .idle
        }
    }

    /// Represents peer connection within HOA ACC Organizer.
    private final class PeerConnection {
        /// The stable identifier for this value.
        let id = UUID()
        /// The active Network.framework connection represented by this peer state.
        let connection: NWConnection
        /// Indicates whether is outbound.
        let isOutbound: Bool
        /// The Bonjour service name used when this device initiates a connection.
        let outboundServiceName: String?

        /// Buffered bytes waiting to be decoded into nearby-sync frames.
        var receiveBuffer = Data()
        /// Indicates whether is ready.
        var isReady = false

        /// The stable device identifier announced by the connected peer.
        var remoteDeviceID: String?
        /// The human-readable device name announced by the connected peer.
        var remoteDisplayName: String?

        /// The current phase of the peer synchronization state machine.
        var syncPhase: SyncPhase = .idle

        /// The hash value used for outgoing attachment hashes.
        var outgoingAttachmentHashes: [String] = []
        /// The index of the attachment currently being sent to the peer.
        var outgoingAttachmentIndex = 0
        /// The open file handle used to stream the current outgoing attachment.
        var outgoingFileHandle: FileHandle?
        /// The hash value used for outgoing content hash.
        var outgoingContentHash: String?
        /// The filename of the attachment currently being sent.
        var outgoingFileName: String?

        /// The URL used for incoming temp url.
        var incomingTempURL: URL?
        /// The URL used for incoming destination url.
        var incomingDestinationURL: URL?
        /// The open file handle used to write the current incoming attachment.
        var incomingFileHandle: FileHandle?
        /// The hash value used for incoming hasher.
        var incomingHasher: SHA256?
        /// The hash value used for incoming content hash.
        var incomingContentHash: String?
        /// The total byte count expected for the current incoming attachment.
        var incomingExpectedBytes: Int64 = 0
        /// The number of attachment bytes received so far.
        var incomingReceivedBytes: Int64 = 0

        /// The count represented by attachment retry count.
        var attachmentRetryCount = 0

        /// The hash value used for required incoming attachment hashes.
        var requiredIncomingAttachmentHashes = Set<String>()

        /// Creates a new `SyncPhase` instance with the supplied values.
        init(
            connection: NWConnection,
            isOutbound: Bool,
            outboundServiceName: String?
        ) {
            self.connection = connection
            self.isOutbound = isOutbound
            self.outboundServiceName =
                outboundServiceName
        }

        /// Closes any open incoming or outgoing attachment file handles owned by the current sync phase.
        func closeTransferFiles() {
            try? outgoingFileHandle?.close()
            outgoingFileHandle = nil

            try? incomingFileHandle?.close()
            incomingFileHandle = nil

            if let temp =
                incomingTempURL {
                try? FileManager.default
                    .removeItem(at: temp)
            }

            incomingTempURL = nil
            incomingDestinationURL = nil
            incomingHasher = nil
            incomingContentHash = nil
            incomingExpectedBytes = 0
            incomingReceivedBytes = 0
        }
    }

    /// The Bonjour service type used by the nearby-sync protocol.
    private let serviceType =
        "_hoaacc._tcp"

    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore

    /// The Bonjour service instance name used for nearby discovery.
    private lazy var serviceName =
        "hoaacc-" +
        String(
            deviceID
                .replacingOccurrences(
                    of: "-",
                    with: ""
                )
                .prefix(12)
        )

    /// The stable identifier used to distinguish this installation during synchronization.
    private let deviceID: String
    /// The human-readable name displayed for this value.
    private let displayName: String

    /// The Network.framework listener that accepts incoming nearby-sync connections.
    private var listener: NWListener?
    /// The Network.framework browser that discovers nearby HOA ACC Organizer devices.
    private var browser: NWBrowser?

    /// The nearby peer states currently known to the sync service.
    private var peers:
        [UUID: PeerConnection] = [:]

    /// The service names for outbound peer connections already being tracked.
    private var outboundServiceNames =
        Set<String>()

    /// The configured automatic nearby-sync cadence.
    private var autoCadence:
        SyncCadence = .weekly

    /// Indicates whether automatic nearby synchronization is enabled.
    private var autoSyncEnabled = true
    /// Indicates whether is running.
    private var isRunning = false

    /// The maximum accepted network-frame header size.
    private let maxHeaderBytes =
        1024 * 1024

    /// The maximum accepted structured sync snapshot size.
    private let maxSnapshotBytes =
        32 * 1024 * 1024

    /// The maximum receive-buffer size retained before malformed input is rejected.
    private let maxBufferedBytes =
        40 * 1024 * 1024

    /// The attachment chunk size used by the nearby-sync protocol.
    private let attachmentChunkBytes =
        256 * 1024

    /// Publishes connected peers so observing views can react when it changes.
    @Published var connectedPeers:
        [String] = []

    /// Publishes sync status so observing views can react when it changes.
    @Published var syncStatus:
        String = "Not connected"

    /// Publishes last sync error so observing views can react when it changes.
    @Published var lastSyncError:
        String?

    /// Publishes sync progress so observing views can react when it changes.
    @Published var syncProgress:
        String = ""

    /// A callback invoked on the main workflow after nearby synchronization finishes successfully.
    var onSyncCompleted:
        (() -> Void)?

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) {
        self.store = store
        self.deviceID =
            Self.loadDeviceID()
        self.displayName =
            Self.localDisplayName()
    }

    /// Creates the Network.framework TCP parameters used for nearby synchronization.
    private func makeParameters()
        -> NWParameters {
        let parameters =
            NWParameters.tcp

        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true

        return parameters
    }

    /// Starts the service and begins the associated workflow.
    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        #if DEBUG
        RuntimeDiagnostics.checkpoint(
            "network.start"
        )
        #else
        RuntimeDiagnostics.checkpoint("Starting")
        #endif

        do {
            let listener =
                try NWListener(
                    using:
                        makeParameters()
                )

            listener.service =
                NWListener.Service(
                    name: serviceName,
                    type: serviceType
                )

            listener.newConnectionHandler = {
                [weak self] connection in

                MainActor.assumeIsolated {
                    self?.addConnection(
                        connection,
                        isOutbound: false,
                        serviceName: nil
                    )
                }
            }

            listener.stateUpdateHandler = {
                [weak self] state in

                MainActor.assumeIsolated {
                    self?
                        .handleListenerState(
                            state
                        )
                }
            }

            listener.start(
                queue: .main
            )

            self.listener =
                listener

            let browser =
                NWBrowser(
                    for:
                        .bonjour(
                            type: serviceType,
                            domain: nil
                        ),
                    using:
                        makeParameters()
                )

            browser.browseResultsChangedHandler = {
                [weak self] results, _ in

                MainActor.assumeIsolated {
                    self?
                        .handleBrowserResults(
                            results
                        )
                }
            }

            browser.stateUpdateHandler = {
                [weak self] state in

                MainActor.assumeIsolated {
                    self?
                        .handleBrowserState(
                            state
                        )
                }
            }

            browser.start(
                queue: .main
            )

            self.browser =
                browser

            publishStatus(
                "Searching for nearby HOA ACC devices…"
            )
        } catch {
            isRunning = false
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "network.start.error"
            )
            publishError(
                "Unable to start Network.framework sync: \(error.localizedDescription)"
            )
            #else
            RuntimeDiagnostics.checkpoint("Network Error")
            
            publishError(
                "Unable to start Network sync."
            )
            #endif
        }
    }

    /// Stops the service and releases active resources.
    func stop() {
        guard
            isRunning ||
            listener != nil ||
            browser != nil ||
            !peers.isEmpty
        else {
            return
        }

        isRunning = false
        #if DEBUG
        RuntimeDiagnostics.checkpoint(
            "network.stop"
        )
        #else
        RuntimeDiagnostics.checkpoint("Service Stopped")
        #endif

        listener?.cancel()
        browser?.cancel()

        listener = nil
        browser = nil

        for peer in peers.values {
            peer.closeTransferFiles()
            peer.connection.cancel()
        }

        peers.removeAll()
        outboundServiceNames.removeAll()

        updateConnectedPeers()
    }

    /// Applies the saved automatic-sync setting and cadence to the nearby-sync service.
    func configureAutomaticSync(
        enabled: Bool,
        cadence: SyncCadence
    ) {
        autoSyncEnabled =
            enabled

        autoCadence =
            cadence
    }

    /// Starts an immediate nearby synchronization attempt with an available peer.
    func syncNow() {
        let readyPeers =
            peers.values.filter {
                $0.isReady &&
                $0.remoteDeviceID != nil
            }

        guard !readyPeers.isEmpty else {
            #if DEBUG
            publishStatus("No nearby HOA ACC device is connected.")
            #else
            publishStatus("No Board Member Detected Nearby")
            #endif
            return
        }

        var started = false

        for peer in readyPeers {
            guard
                !peer.syncPhase.isBusy
            else {
                continue
            }

            started = true
            sendSnapshot(
                to: peer
            )
        }

        if !started {
            publishStatus(
                "A sync is already in progress."
            )
        }
    }

    // MARK: - Listener / browser

    /// Handles Network.framework listener state changes and publishes user-facing status.
    private func handleListenerState(
        _ state: NWListener.State
    ) {
        switch state {
        case .ready:
            #if DEBUG
            RuntimeDiagnostics.checkpoint("network.listener.ready")
            #else
            RuntimeDiagnostics.checkpoint("Ready to connect")
            #endif

            if !hasConnectedPeer {
                publishStatus(
                    "Nearby sync is available."
                )
            }

        case .waiting(let error):
            publishError(
                "Nearby listener waiting: \(error.localizedDescription)"
            )

        case .failed(let error):
            publishError(
                "Nearby listener failed: \(error.localizedDescription)"
            )

            listener?.cancel()
            listener = nil

        case .cancelled:
            break

        default:
            break
        }
    }

    /// Handles Bonjour browser state changes and publishes user-facing status.
    private func handleBrowserState(
        _ state: NWBrowser.State
    ) {
        switch state {
        case .ready:
            if !hasConnectedPeer {
                publishStatus(
                    "Searching for nearby HOA ACC devices…"
                )
            }

        case .waiting(let error):
            publishError(
                "Nearby discovery waiting: \(error.localizedDescription)"
            )

        case .failed(let error):
            publishError(
                "Nearby discovery failed: \(error.localizedDescription)"
            )

            browser?.cancel()
            browser = nil

        case .cancelled:
            break

        default:
            break
        }
    }

    /// Reconciles the current Bonjour discovery results with the active peer set.
    private func handleBrowserResults(
        _ results:
            Set<NWBrowser.Result>
    ) {
        let discoveredNames =
            results.compactMap {
                result -> String? in

                guard
                    case let .service(
                        name,
                        _,
                        _,
                        _
                    ) = result.endpoint,
                    name != serviceName
                else {
                    return nil
                }

                return name
            }
            .sorted()

        if !hasConnectedPeer {
            if discoveredNames.isEmpty {
                publishStatus(
                    "Searching for nearby HOA ACC devices…"
                )
            } else {
                #if DEBUG
                publishStatus("Discovered: " + discoveredNames.joined(separator: ", "))
                #else
                publishStatus("Board Member Discovered")
                #endif
            }
        }

        for result in results {
            guard
                case let .service(
                    name,
                    _,
                    _,
                    _
                ) =
                    result.endpoint
            else {
                continue
            }

            guard
                name != serviceName
            else {
                continue
            }

            // Exactly one side initiates a connection for a device pair.
            guard
                serviceName
                    .localizedStandardCompare(
                        name
                    )
                    == .orderedAscending
            else {
                continue
            }

            guard
                !outboundServiceNames
                    .contains(name)
            else {
                continue
            }

            outboundServiceNames
                .insert(name)

            let connection =
                NWConnection(
                    to: result.endpoint,
                    using:
                        makeParameters()
                )

            addConnection(
                connection,
                isOutbound: true,
                serviceName: name
            )
        }
    }

    // MARK: - Connections

    /// Registers a Network.framework connection and begins its receive/state pipeline.
    private func addConnection(
        _ connection: NWConnection,
        isOutbound: Bool,
        serviceName: String?
    ) {
        let peer =
            PeerConnection(
                connection: connection,
                isOutbound: isOutbound,
                outboundServiceName:
                    serviceName
            )

        peers[peer.id] =
            peer

        let peerID =
            peer.id

        connection.stateUpdateHandler = {
            [weak self] state in

            MainActor.assumeIsolated {
                self?
                    .handleConnectionState(
                        peerID: peerID,
                        state: state
                    )
            }
        }

        connection.start(
            queue: .main
        )

        receiveNext(
            from: peer
        )

        updateConnectedPeers()
    }

    /// Handles a peer connection state transition and advances or tears down synchronization.
    private func handleConnectionState(
        peerID: UUID,
        state: NWConnection.State
    ) {
        guard let peer =
            peers[peerID]
        else {
            return
        }

        switch state {
        case .ready:
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "network.connection.ready"
            )
            #endif

            peer.isReady = true

            sendHello(
                to: peer
            )

            updateConnectedPeers()

        case .failed(let error):
            publishError(
                "Nearby connection failed: \(error.localizedDescription)"
            )

            removePeer(
                peer
            )

        case .cancelled:
            removePeer(
                peer
            )

        default:
            break
        }
    }

    /// Removes a peer and releases all connection/file resources associated with it.
    private func removePeer(
        _ peer: PeerConnection
    ) {
        peer.closeTransferFiles()

        peers.removeValue(
            forKey: peer.id
        )

        if let serviceName =
            peer.outboundServiceName {
            outboundServiceNames
                .remove(serviceName)
        }

        updateConnectedPeers()
    }

    /// Requests the next block of bytes from a connected peer.
    private func receiveNext(
        from peer: PeerConnection
    ) {
        let peerID = peer.id

        peer.connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1024
        ) {
            [weak self] data, _, isComplete, error in

            MainActor.assumeIsolated {
                guard
                    let self,
                    let current =
                        self.peers[
                            peerID
                        ]
                else {
                    return
                }

                if let data,
                   !data.isEmpty {
                    current.receiveBuffer
                        .append(data)

                    if current.receiveBuffer.count >
                        self.maxBufferedBytes {
                        self.publishError(
                            "Nearby sync exceeded the receive-buffer safety limit."
                        )

                        current.connection.cancel()
                        return
                    }

                    self.processFrames(
                        for: current
                    )
                }

                if let error {
                    self.publishError(
                        "Nearby receive failed: \(error.localizedDescription)"
                    )

                    current.connection.cancel()
                    return
                }

                if isComplete {
                    current.connection.cancel()
                    return
                }

                self.receiveNext(
                    from: current
                )
            }
        }
    }

    // MARK: - Frame protocol

    /// Parses buffered network bytes into complete framed sync messages.
    private func processFrames(
        for peer: PeerConnection
    ) {
        while true {
            guard
                peer.receiveBuffer.count >= 4
            else {
                return
            }

            guard
                let headerLength =
                    peer.receiveBuffer
                        .readUInt32BE(
                            at: 0
                        )
            else {
                peer.connection.cancel()
                return
            }

            let headerCount =
                Int(headerLength)

            guard
                headerCount > 0,
                headerCount <=
                    maxHeaderBytes
            else {
                peer.connection.cancel()
                return
            }

            let headerEnd =
                4 + headerCount

            guard
                peer.receiveBuffer.count >=
                    headerEnd
            else {
                return
            }

            guard
                let headerData =
                    peer.receiveBuffer
                        .data(
                            inOffsets:
                                4..<headerEnd
                        )
            else {
                peer.connection.cancel()
                return
            }

            guard
                let header =
                    try? JSONDecoder()
                        .decode(
                            NetworkSyncFrameHeader.self,
                            from:
                                headerData
                        ),
                header.payloadLength >= 0
            else {
                peer.connection.cancel()
                return
            }

            let payloadLimit =
                header.kind == .snapshot
                ? maxSnapshotBytes
                : max(
                    attachmentChunkBytes * 2,
                    2 * 1024 * 1024
                )

            guard
                header.payloadLength <=
                    payloadLimit
            else {
                publishError(
                    "A nearby sync frame exceeded its safety limit."
                )

                peer.connection.cancel()
                return
            }

            let (
                totalLength,
                overflow
            ) = headerEnd
                .addingReportingOverflow(
                    header.payloadLength
                )

            guard !overflow else {
                peer.connection.cancel()
                return
            }

            guard
                peer.receiveBuffer.count >=
                    totalLength
            else {
                return
            }

            guard
                let payload =
                    peer.receiveBuffer
                        .data(
                            inOffsets:
                                headerEnd
                                ..<
                                totalLength
                        )
            else {
                peer.connection.cancel()
                return
            }

            peer.receiveBuffer
                .discardPrefix(
                    totalLength
                )

            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "network.frame.\(header.kind.rawValue)"
            )
            #else
            RuntimeDiagnostics.checkpoint("Malfunction 54.")
            #endif

            handleFrame(
                header,
                payload: payload,
                from: peer
            )
        }
    }

    /// Encodes and sends one framed nearby-sync message.
    private func sendFrame(
        kind:
            NetworkSyncFrameHeader.Kind,
        payload: Data = Data(),
        contentHash: String? = nil,
        to peer: PeerConnection,
        completion:
            (() -> Void)? = nil
    ) {
        guard peer.isReady else {
            return
        }

        do {
            let header =
                NetworkSyncFrameHeader(
                    kind: kind,
                    payloadLength:
                        payload.count,
                    contentHash:
                        contentHash
                )

            let headerData =
                try JSONEncoder()
                    .encode(header)

            guard
                headerData.count <=
                    maxHeaderBytes
            else {
                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Sync frame header is too large."
                    ]
                )
            }

            var frame = Data()
            frame.reserveCapacity(
                4 +
                headerData.count +
                payload.count
            )

            frame.appendUInt32BE(
                UInt32(
                    headerData.count
                )
            )

            frame.append(
                headerData
            )

            frame.append(
                payload
            )

            let peerID =
                peer.id

            peer.connection.send(
                content: frame,
                completion:
                    .contentProcessed {
                        [weak self] error in

                        MainActor.assumeIsolated {
                            guard
                                let self,
                                let peer =
                                    self.peers[
                                        peerID
                                    ]
                            else {
                                return
                            }

                            if let error {
                                self.publishError(
                                    "Nearby send failed: \(error.localizedDescription)"
                                )

                                peer.connection.cancel()
                                return
                            }

                            completion?()
                        }
                    }
            )
        } catch {
            publishError(
                "Unable to prepare sync frame: \(error.localizedDescription)"
            )
        }
    }

    /// Sends a protocol-level error message to the connected peer.
    private func sendTextError(
        _ message: String,
        to peer: PeerConnection
    ) {
        let data =
            Data(
                message.utf8
            )

        sendFrame(
            kind: .syncError,
            payload: data,
            to: peer
        )
    }

    /// Dispatches an incoming sync frame to the handler for its frame kind.
    private func handleFrame(
        _ header:
            NetworkSyncFrameHeader,
        payload: Data,
        from peer: PeerConnection
    ) {
        switch header.kind {
        case .hello:
            receiveHello(
                payload,
                from: peer
            )

        case .snapshot:
            receiveSnapshot(
                payload,
                from: peer
            )

        case .requestAttachments:
            receiveAttachmentRequest(
                payload,
                from: peer
            )

        case .attachmentStart:
            receiveAttachmentStart(
                payload,
                from: peer
            )

        case .attachmentChunk:
            receiveAttachmentChunk(
                payload,
                contentHash:
                    header.contentHash,
                from: peer
            )

        case .attachmentEnd:
            receiveAttachmentEnd(
                contentHash:
                    header.contentHash,
                from: peer
            )

        case .attachmentsFinished:
            finishReceivingAttachments(
                from: peer
            )

        case .syncComplete:
            completeSync(
                with: peer
            )

        case .syncError:
            receiveSyncError(
                payload,
                from: peer
            )
        }
    }

    // MARK: - Hello / duplicate connection handling

    /// Sends this device’s identity handshake to a newly connected peer.
    private func sendHello(
        to peer: PeerConnection
    ) {
        do {
            let hello =
                NetworkSyncHello(
                    deviceID:
                        deviceID,
                    displayName:
                        displayName,
                    serviceName:
                        serviceName
                )

            sendFrame(
                kind: .hello,
                payload:
                    try JSONEncoder()
                        .encode(hello),
                to: peer
            )
        } catch {
            publishError(
                "Unable to identify this device: \(error.localizedDescription)"
            )
        }
    }

    /// Validates and stores the remote peer’s identity handshake.
    private func receiveHello(
        _ payload: Data,
        from peer: PeerConnection
    ) {
        guard
            let hello =
                try? JSONDecoder()
                    .decode(
                        NetworkSyncHello.self,
                        from: payload
                    )
        else {
            peer.connection.cancel()
            return
        }

        if hello.deviceID ==
            deviceID {
            peer.connection.cancel()
            return
        }

        peer.remoteDeviceID =
            hello.deviceID

        peer.remoteDisplayName =
            hello.displayName

        removeDuplicateConnections(
            for: peer
        )

        updateConnectedPeers()

        if peer.isOutbound &&
            autoSyncEnabled {
            do {
                let state =
                    try store.fetchSyncState()

                guard
                    state.lastSuccessfulSyncAt != nil
                else {
                    publishStatus(
                        "Connected to \(peerName(peer)). Tap Sync Now for the first sync."
                    )
                    return
                }

                if try store.syncIsDue(
                    cadence:
                        autoCadence
                ) {
                    sendSnapshot(
                        to: peer
                    )
                }
            } catch {
                publishError(
                    "Unable to check automatic sync schedule: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Resolves duplicate inbound/outbound connections so only one session remains per device.
    private func removeDuplicateConnections(
        for peer: PeerConnection
    ) {
        guard
            let remoteID =
                peer.remoteDeviceID
        else {
            return
        }

        let duplicates =
            peers.values.filter {
                $0.id != peer.id &&
                $0.remoteDeviceID ==
                    remoteID
            }

        for other in duplicates {
            let keepOutbound =
                deviceID <
                remoteID

            let keepPeer =
                keepOutbound
                ? (
                    peer.isOutbound
                    ? peer
                    : other
                )
                : (
                    peer.isOutbound
                    ? other
                    : peer
                )

            let remove =
                keepPeer.id ==
                    peer.id
                ? other
                : peer

            remove.connection
                .cancel()
        }
    }

    /// Returns the attachment content hashes already present locally.
    private func attachmentHashes(
        in package: FullDataExportPackage
    ) -> Set<String> {
        var hashes = Set<String>()

        for lot in package.lots {
            for violation in
                lot.violations {
                for attachment in
                    violation.attachments {
                    if !attachment
                        .contentHash
                        .isEmpty {
                        hashes.insert(
                            attachment
                                .contentHash
                        )
                    }
                }
            }

            for application in
                lot.accApplications {
                for attachment in
                    application.attachments {
                    if !attachment
                        .contentHash
                        .isEmpty {
                        hashes.insert(
                            attachment
                                .contentHash
                        )
                    }
                }
            }
        }

        return hashes
    }

    // MARK: - Snapshot sync

    /// Encodes and sends the current structured full-data snapshot to the peer.
    private func sendSnapshot(
        to peer: PeerConnection
    ) {
        guard
            !peer.syncPhase.isBusy
        else {
            return
        }

        peer.syncPhase =
            .sendingSnapshot

        peer.requiredIncomingAttachmentHashes
            .removeAll()

        peer.attachmentRetryCount = 0

        lastSyncError = nil
        setProgress(
            "Preparing metadata…"
        )

        do {
            let package =
                try store
                    .buildFullDataExportPackage(
                        includeAttachmentData:
                            false
                    )

            let data =
                try JSONEncoder()
                    .encode(package)

            guard
                data.count <=
                    maxSnapshotBytes
            else {
                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The metadata snapshot is too large for nearby sync. Create a full backup instead."
                    ]
                )
            }

            publishStatus(
                "Sending metadata to \(peerName(peer))…"
            )

            setProgress(
                "\(data.count.formatted()) bytes of metadata"
            )

            sendFrame(
                kind: .snapshot,
                payload: data,
                to: peer
            ) {
                [weak self, weak peer] in

                guard
                    let self,
                    let peer
                else {
                    return
                }

                peer.syncPhase =
                    .waitingForAttachmentRequest

                self.publishStatus(
                    "Metadata sent. Waiting for \(self.peerName(peer))…"
                )
            }
        } catch {
            peer.syncPhase =
                .idle

            publishError(
                "Sync failed: \(error.localizedDescription)"
            )
        }
    }

    /// Decodes and imports the structured snapshot received from a peer.
    private func receiveSnapshot(
        _ payload: Data,
        from peer: PeerConnection
    ) {
        guard
            !peer.syncPhase.isBusy
        else {
            let message =
                "This device is already processing another sync with \(peerName(peer)). Try Sync Now again after it finishes."

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
            return
        }

        peer.syncPhase =
            .receivingSnapshot

        peer.attachmentRetryCount = 0

        lastSyncError = nil
        setProgress(
            "Applying metadata…"
        )

        publishStatus(
            "Applying data from \(peerName(peer))…"
        )

        do {
            let package =
                try JSONDecoder()
                    .decode(
                        FullDataExportPackage.self,
                        from: payload
                    )

            let requiredHashes =
                attachmentHashes(
                    in: package
                )

            peer.requiredIncomingAttachmentHashes =
                requiredHashes

            try store
                .importFullDataExportPackage(
                    package,
                    sourceFileName:
                        "Nearby Network Sync - \(peerName(peer))"
                )

            let missing =
                try store
                    .missingAttachmentHashes(
                        requiredHashes:
                            requiredHashes
                    )

            if missing.isEmpty {
                try recordLocalSync(
                    with: peer
                )

                peer.syncPhase =
                    .idle

                sendFrame(
                    kind: .syncComplete,
                    to: peer
                )
            } else {
                peer.syncPhase =
                    .receivingAttachments

                requestAttachments(
                    missing,
                    from: peer
                )
            }
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to apply nearby sync on this device: \(error.localizedDescription)"

            publishError(message)

            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Requests only attachment hashes that are required by the imported snapshot but missing locally.
    private func requestAttachments(
        _ hashes: [String],
        from peer: PeerConnection
    ) {
        do {
            let data =
                try JSONEncoder()
                    .encode(hashes)

            setProgress(
                "Waiting for \(hashes.count) attachment(s)"
            )

            sendFrame(
                kind:
                    .requestAttachments,
                payload: data,
                to: peer
            )

            publishStatus(
                "Requesting \(hashes.count) attachment(s) from \(peerName(peer))…"
            )
        } catch {
            peer.syncPhase =
                .idle

            publishError(
                "Unable to request attachments: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Sequential, chunked attachment sending

    /// Processes the peer’s list of requested attachment hashes.
    private func receiveAttachmentRequest(
        _ payload: Data,
        from peer: PeerConnection
    ) {
        do {
            let hashes =
                try JSONDecoder()
                    .decode(
                        [String].self,
                        from: payload
                    )

            peer.syncPhase =
                .sendingAttachments

            peer.outgoingAttachmentHashes =
                hashes

            peer.outgoingAttachmentIndex =
                0

            setProgress(
                "Preparing \(hashes.count) attachment(s)"
            )

            sendNextAttachment(
                to: peer
            )
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to read attachment request: \(error.localizedDescription)"

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Advances to the next requested attachment and opens it for chunked transfer.
    private func sendNextAttachment(
        to peer: PeerConnection
    ) {
        try? peer.outgoingFileHandle?
            .close()

        peer.outgoingFileHandle =
            nil

        guard
            peer.outgoingAttachmentIndex <
                peer.outgoingAttachmentHashes.count
        else {
            peer.syncPhase =
                .waitingForCompletion

            setProgress(
                "Waiting for completion acknowledgement"
            )

            sendFrame(
                kind:
                    .attachmentsFinished,
                to: peer
            )

            return
        }

        let index =
            peer.outgoingAttachmentIndex

        let hash =
            peer.outgoingAttachmentHashes[
                index
            ]

        peer.outgoingAttachmentIndex += 1

        do {
            guard
                let info =
                    try store
                        .attachmentTransferInfo(
                            contentHash:
                                hash
                        )
            else {
                sendNextAttachment(
                    to: peer
                )
                return
            }

            let url =
                try store
                    .attachmentURL(
                        fileName:
                            info.fileName
                    )

            guard
                FileManager.default
                    .fileExists(
                        atPath:
                            url.path
                    )
            else {
                sendNextAttachment(
                    to: peer
                )
                return
            }

            let attributes =
                try FileManager.default
                    .attributesOfItem(
                        atPath: url.path
                    )

            let byteCount =
                (attributes[
                    .size
                ] as? NSNumber)?
                    .int64Value
                ?? 0

            let handle =
                try FileHandle(
                    forReadingFrom: url
                )

            peer.outgoingFileHandle =
                handle

            peer.outgoingContentHash =
                hash

            peer.outgoingFileName =
                info.fileName

            let start =
                NetworkAttachmentStart(
                    contentHash:
                        hash,
                    fileName:
                        info.fileName,
                    byteCount:
                        byteCount
                )

            let startData =
                try JSONEncoder()
                    .encode(start)

            let position =
                index + 1

            setProgress(
                "Attachment \(position) of \(peer.outgoingAttachmentHashes.count)"
            )

            publishStatus(
                "Sending \(info.fileName) to \(peerName(peer))…"
            )

            sendFrame(
                kind:
                    .attachmentStart,
                payload:
                    startData,
                contentHash:
                    hash,
                to: peer
            ) {
                [weak self, weak peer] in

                guard
                    let self,
                    let peer
                else {
                    return
                }

                self.sendNextAttachmentChunk(
                    to: peer
                )
            }
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to start attachment transfer: \(error.localizedDescription)"

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Reads and sends the next bounded chunk of the current attachment.
    private func sendNextAttachmentChunk(
        to peer: PeerConnection
    ) {
        guard
            let handle =
                peer.outgoingFileHandle,
            let hash =
                peer.outgoingContentHash
        else {
            sendNextAttachment(
                to: peer
            )
            return
        }

        do {
            let chunk =
                try handle.read(
                    upToCount:
                        attachmentChunkBytes
                )
                ?? Data()

            if chunk.isEmpty {
                try handle.close()

                peer.outgoingFileHandle =
                    nil

                sendFrame(
                    kind:
                        .attachmentEnd,
                    contentHash:
                        hash,
                    to: peer
                ) {
                    [weak self, weak peer] in

                    guard
                        let self,
                        let peer
                    else {
                        return
                    }

                    self.sendNextAttachment(
                        to: peer
                    )
                }

                return
            }

            sendFrame(
                kind:
                    .attachmentChunk,
                payload:
                    chunk,
                contentHash:
                    hash,
                to: peer
            ) {
                [weak self, weak peer] in

                guard
                    let self,
                    let peer
                else {
                    return
                }

                self.sendNextAttachmentChunk(
                    to: peer
                )
            }
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to read attachment while syncing: \(error.localizedDescription)"

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    // MARK: - Chunked attachment receiving

    /// Creates temporary state for an incoming attachment announced by the peer.
    private func receiveAttachmentStart(
        _ payload: Data,
        from peer: PeerConnection
    ) {
        do {
            let start =
                try JSONDecoder()
                    .decode(
                        NetworkAttachmentStart.self,
                        from: payload
                    )

            guard
                let info =
                    try store
                        .attachmentTransferInfo(
                            contentHash:
                                start.contentHash
                        )
            else {
                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Attachment metadata was not found for \(start.contentHash)."
                    ]
                )
            }

            try? peer.incomingFileHandle?
                .close()

            if let oldTemp =
                peer.incomingTempURL {
                try? FileManager.default
                    .removeItem(
                        at: oldTemp
                    )
            }

            let destination =
                try store
                    .attachmentURL(
                        fileName:
                            info.fileName
                    )

            let temp =
                destination
                    .appendingPathExtension(
                        "syncpart"
                    )

            try? FileManager.default
                .removeItem(
                    at: temp
                )

            FileManager.default
                .createFile(
                    atPath:
                        temp.path,
                    contents:
                        Data()
                )

            let handle =
                try FileHandle(
                    forWritingTo:
                        temp
                )

            peer.incomingTempURL =
                temp

            peer.incomingDestinationURL =
                destination

            peer.incomingFileHandle =
                handle

            peer.incomingHasher =
                SHA256()

            peer.incomingContentHash =
                start.contentHash

            peer.incomingExpectedBytes =
                start.byteCount

            peer.incomingReceivedBytes =
                0

            publishStatus(
                "Receiving \(info.fileName) from \(peerName(peer))…"
            )
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to prepare incoming attachment: \(error.localizedDescription)"

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Appends one incoming attachment chunk after validating size and protocol state.
    private func receiveAttachmentChunk(
        _ payload: Data,
        contentHash: String?,
        from peer: PeerConnection
    ) {
        guard
            let hash =
                contentHash,
            hash ==
                peer.incomingContentHash,
            let handle =
                peer.incomingFileHandle
        else {
            let message =
                "Received an attachment chunk out of sequence."

            publishError(message)
            sendTextError(
                message,
                to: peer
            )

            peer.connection.cancel()
            return
        }

        do {
            try handle.write(
                contentsOf:
                    payload
            )

            peer.incomingHasher?
                .update(
                    data:
                        payload
                )

            peer.incomingReceivedBytes +=
                Int64(
                    payload.count
                )
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to write incoming attachment: \(error.localizedDescription)"

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Finalizes, validates, and installs a fully received attachment file.
    private func receiveAttachmentEnd(
        contentHash: String?,
        from peer: PeerConnection
    ) {
        guard
            let expectedHash =
                contentHash,
            expectedHash ==
                peer.incomingContentHash,
            let temp =
                peer.incomingTempURL,
            let destination =
                peer.incomingDestinationURL,
            let hasher =
                peer.incomingHasher
        else {
            let message =
                "Attachment completion arrived out of sequence."

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
            return
        }

        do {
            try peer.incomingFileHandle?
                .close()

            peer.incomingFileHandle =
                nil

            let digest =
                hasher.finalize()
                    .map {
                        String(
                            format:
                                "%02x",
                            $0
                        )
                    }
                    .joined()

            guard
                digest.caseInsensitiveCompare(
                    expectedHash
                ) ==
                    .orderedSame
            else {
                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Attachment hash verification failed."
                    ]
                )
            }

            guard
                peer.incomingReceivedBytes ==
                    peer.incomingExpectedBytes
            else {
                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 5,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Attachment transfer ended before all bytes were received."
                    ]
                )
            }

            if FileManager.default
                .fileExists(
                    atPath:
                        destination.path
                ) {
                try FileManager.default
                    .removeItem(
                        at:
                            destination
                    )
            }

            try FileManager.default
                .moveItem(
                    at: temp,
                    to:
                        destination
                )

            clearIncomingAttachment(
                for: peer
            )
        } catch {
            let message =
                "Unable to finish incoming attachment: \(error.localizedDescription)"

            clearIncomingAttachment(
                for: peer
            )

            peer.syncPhase =
                .idle

            publishError(message)
            sendTextError(
                message,
                to: peer
            )
        }
    }

    /// Closes and removes temporary state for a partial incoming attachment.
    private func clearIncomingAttachment(
        for peer: PeerConnection
    ) {
        try? peer.incomingFileHandle?
            .close()

        peer.incomingFileHandle =
            nil

        peer.incomingTempURL =
            nil

        peer.incomingDestinationURL =
            nil

        peer.incomingHasher =
            nil

        peer.incomingContentHash =
            nil

        peer.incomingExpectedBytes =
            0

        peer.incomingReceivedBytes =
            0
    }

    /// Completes the receive phase after every requested attachment has arrived.
    private func finishReceivingAttachments(
        from peer: PeerConnection
    ) {
        do {
            let remaining =
                try store
                    .missingAttachmentHashes(
                        requiredHashes:
                            peer
                                .requiredIncomingAttachmentHashes
                    )

            if !remaining.isEmpty {
                if peer.attachmentRetryCount <
                    1 {
                    peer.attachmentRetryCount +=
                        1

                    requestAttachments(
                        remaining,
                        from: peer
                    )
                    return
                }

                throw NSError(
                    domain:
                        "HOAACCNetworkSync",
                    code: 6,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The other device could not provide \(remaining.count) required attachment(s)."
                    ]
                )
            }

            try recordLocalSync(
                with: peer
            )

            peer.syncPhase =
                .idle

            sendFrame(
                kind: .syncComplete,
                to: peer
            )
        } catch {
            peer.syncPhase =
                .idle

            let message =
                "Unable to finish nearby sync: \(error.localizedDescription)"

            publishError(message)

            sendTextError(
                message,
                to: peer
            )
        }
    }

    // MARK: - Completion / error

    /// Records a successful sync, clears transient peer state, and notifies the application model.
    private func completeSync(
        with peer: PeerConnection
    ) {
        do {
            try recordLocalSync(
                with: peer
            )

            peer.syncPhase =
                .idle
        } catch {
            peer.syncPhase =
                .idle

            publishError(
                "Unable to record sync completion: \(error.localizedDescription)"
            )
        }
    }

    /// Processes a protocol-level error reported by the remote peer.
    private func receiveSyncError(
        _ payload: Data,
        from peer: PeerConnection
    ) {
        peer.syncPhase =
            .idle

        peer.requiredIncomingAttachmentHashes
            .removeAll()

        let message =
            String(
                data: payload,
                encoding: .utf8
            )
            ?? "The other device reported a sync error."

        publishError(
            "\(peerName(peer)): \(message)"
        )
    }

    /// Records local sync in persistent application history.
    private func recordLocalSync(
        with peer: PeerConnection
    ) throws {
        try store
            .recordSuccessfulSync(
                method:
                    "Local Network",
                peerName:
                    peerName(peer)
            ) // Network.framework

        lastSyncError = nil
        syncProgress = ""

        peer.requiredIncomingAttachmentHashes
            .removeAll()

        publishStatus(
            "Sync completed with \(peerName(peer))."
        )
        #if DEBUG

        RuntimeDiagnostics.checkpoint(
            "network.sync.complete"
        )
        #else
        RuntimeDiagnostics.checkpoint("Sync Complete")
        
        #endif
        

        onSyncCompleted?()
    }

    // MARK: - UI helpers

    /// Indicates whether has connected peer.
    private var hasConnectedPeer:
        Bool {
        peers.values.contains {
            $0.isReady &&
            $0.remoteDeviceID != nil
        }
    }

    /// Updates connected peers while preserving workflow and audit requirements.
    private func updateConnectedPeers() {
        connectedPeers =
            peers.values
                .filter {
                    $0.isReady &&
                    $0.remoteDeviceID != nil
                }
                .map {
                    peerName($0)
                }
                .sorted()

        if connectedPeers.isEmpty {
            if listener != nil &&
                browser != nil {
                syncStatus =
                    UserFacingStatus.syncStatus(
                        "Searching for nearby HOA ACC devices…"
                    )
            } else {
                syncStatus =
                    UserFacingStatus.syncStatus(
                        "Nearby sync is not running."
                    )
            }
        } else if
            !peers.values.contains(
                where: {
                    $0.syncPhase.isBusy
                }
            ) {
            syncStatus =
                UserFacingStatus.syncStatus(
                    "Connected: " +
                    connectedPeers.joined(
                        separator: ", "
                    )
                )
        }
    }

    /// Returns the best human-readable display name available for a peer.
    private func peerName(
        _ peer: PeerConnection
    ) -> String {
        peer.remoteDisplayName
        ?? peer.outboundServiceName
        ?? "Nearby Device"
    }

    /// Publishes a sync status update on the main actor.
    private func publishStatus(
        _ value: String
    ) {
        syncStatus =
            UserFacingStatus.syncStatus(
                value
            )
    }

    /// Publishes a sync error on the main actor.
    private func publishError(
        _ value: String
    ) {
        let displayValue =
            UserFacingStatus.syncError(
                value
            )

        lastSyncError = displayValue
        syncStatus = displayValue

        // Keep the full technical error in Xcode / Console even when the
        // Release UI shows a simpler explanation.
        print(
            "HOA ACC Sync Error: \(value)"
        )

        RuntimeDiagnostics.checkpoint(
            "network.sync.error"
        )
    }

    /// Updates the published nearby-sync progress value.
    private func setProgress(
        _ value: String
    ) {
        syncProgress =
            UserFacingStatus.syncProgress(
                value
            )
    }

    /// Loads device id from its configured source.
    private static func loadDeviceID()
        -> String {
        let key =
            "hoaacc.network.deviceID"

        if let existing =
            UserDefaults.standard
                .string(
                    forKey: key
                ),
           !existing.isEmpty {
            return existing
        }

        let newValue =
            UUID().uuidString

        UserDefaults.standard.set(
            newValue,
            forKey: key
        )

        return newValue
    }

    /// Returns the current device name used in nearby-sync identity messages.
    private static func localDisplayName()
        -> String {
        #if os(iOS)
        let value =
            UIDevice.current.name

        return value.isEmpty
            ? "HOA ACC iOS Device"
            : value
        #else
        return Host.current()
            .localizedName
            ?? ProcessInfo
                .processInfo
                .hostName
        #endif
    }
}

/// Adds HOA ACC Organizer behavior to `Data`.
private extension Data {
    /// Appends a 32-bit integer in network byte order to framed protocol data.
    mutating func appendUInt32BE(
        _ value: UInt32
    ) {
        var bigEndian =
            value.bigEndian

        Swift.withUnsafeBytes(
            of: &bigEndian
        ) {
            append(
                contentsOf: $0
            )
        }
    }

    /// Reads u int32 be for `Data`.
    func readUInt32BE(
        at offset: Int
    ) -> UInt32? {
        guard
            offset >= 0,
            offset <= count - 4
        else {
            return nil
        }

        let first =
            index(
                startIndex,
                offsetBy: offset
            )

        let second =
            index(
                first,
                offsetBy: 1
            )

        let third =
            index(
                first,
                offsetBy: 2
            )

        let fourth =
            index(
                first,
                offsetBy: 3
            )

        return
            (UInt32(self[first]) << 24) |
            (UInt32(self[second]) << 16) |
            (UInt32(self[third]) << 8) |
            UInt32(self[fourth])
    }

    /// Returns a slice of `Data` beginning at the requested offset while safely validating bounds.
    func data(
        inOffsets range: Range<Int>
    ) -> Data? {
        guard
            range.lowerBound >= 0,
            range.upperBound >=
                range.lowerBound,
            range.upperBound <= count
        else {
            return nil
        }

        let lower =
            index(
                startIndex,
                offsetBy:
                    range.lowerBound
            )

        let upper =
            index(
                startIndex,
                offsetBy:
                    range.upperBound
            )

        return Data(
            self[lower..<upper]
        )
    }

    /// Removes the specified number of bytes from the front of the receive buffer.
    mutating func discardPrefix(
        _ length: Int
    ) {
        guard length > 0 else {
            return
        }

        guard length < count else {
            removeAll(
                keepingCapacity: true
            )
            return
        }

        let newStart =
            index(
                startIndex,
                offsetBy: length
            )

        self =
            Data(
                self[
                    newStart
                    ..<
                    endIndex
                ]
            )
    }
}

import FamilyControls
import Foundation
import Observation

enum P0UserMessage: Equatable {
    case ready
    case authorizationApproved
    case authorizationNeeded
    case authorizationRevoked
    case selectionSaved
    case localCommandDispatched(ShieldCommandKind)
    case shieldRequestReceived
    case recoveryNeeded
}

@MainActor
@Observable
final class P0CapabilityModel {
    var selection: FamilyActivitySelection
    var isPickerPresented = false
    private(set) var state: P0CapabilityState
    private(set) var message: P0UserMessage = .ready
    private(set) var latestIntentContext: ShieldIntentContext?
    private(set) var latestIntentRecordID: UUID?

    private let authorizationClient = FamilyControlsAuthorizationClient()
    private let selectionStore = ActivitySelectionStore()
    private let shieldClient = ShieldProtectionClient()
    private let inboxReader = IntentInboxReader()
    private let appGroupStore: AppGroupStore?

    /// This is an explicit Debug + Simulator fixture for exercising app-owned
    /// reducer/UI paths. It never calls AuthorizationCenter, persists a fake
    /// selection, or writes ManagedSettings on a production device.
    private var simulatorClosureDemoEnabled: Bool {
#if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("--p0-simulator-closure-demo")
#else
        false
#endif
    }

    private var simulatorClosureSelectionCount: Int {
#if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--p0-simulator-selection=0") ? 0 : 1
#else
        return 0
#endif
    }

    init() {
        appGroupStore = try? AppGroupStore()
        selection = selectionStore.load()

        let restoredSnapshot: P0SessionSnapshot?
        if let appGroupStore {
            restoredSnapshot = try? appGroupStore.read(
                P0SessionSnapshot.self,
                forKey: AppGroupKeys.sessionSnapshot
            )
        } else {
            restoredSnapshot = nil
        }

        if let snapshot = restoredSnapshot {
            state = P0CapabilityState(
                sessionID: snapshot.sessionID,
                generation: snapshot.generation,
                phase: snapshot.phase,
                authorization: .notDetermined,
                selectedItemCount: snapshot.selectedItemCount,
                lastConsumedIntentID: snapshot.lastConsumedIntentID,
                lastCommandReceipt: snapshot.lastCommandReceipt,
                latestErrorCode: nil
            )
        } else {
            state = .initial()
        }

        observeAuthorization()
        selectionChanged()
        if simulatorClosureDemoEnabled,
           let outcome = ProcessInfo.processInfo.arguments.first(where: {
               $0 == "--p0-simulator-relock=failed" || $0 == "--p0-simulator-relock=unknown"
           }) {
            reduce(.commandRejected(code: outcome == "--p0-simulator-relock=failed"
                ? "simulator_relock_failed" : "simulator_relock_unknown"))
        }
    }

    var authorizationState: P0AuthorizationState {
        state.authorization
    }

    var selectedItemCount: Int {
        if simulatorClosureDemoEnabled { return simulatorClosureSelectionCount }
        return selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    /// Focus normally stays quiet after a local protection request. Surface a
    /// warning only when the capability state itself reports that the request
    /// cannot be relied on; this remains presentation data and never changes
    /// the protection state machine.
    var needsFocusProtectionWarning: Bool {
        state.phase == .recoveryRequired
            || state.latestErrorCode != nil
            || (
                state.phase == .localProtectionRequested
                    && state.authorization != .approved
            )
    }

    func requestAuthorization() async {
        let startsNewSession = state.authorization != .approved
        let requestFailed: Bool
        do {
            try await authorizationClient.requestIndividualAuthorization()
            requestFailed = false
        } catch {
            requestFailed = true
        }
        let mapped = currentAuthorizationState
        if startsNewSession, mapped == .approved {
            reduce(.authorizationRestored(sessionID: UUID()))
        } else {
            reduce(.authorizationObserved(mapped))
        }
        if requestFailed {
            reduce(.commandRejected(code: "authorization_request_failed"))
            message = .recoveryNeeded
            return
        }
        message = state.authorization == .approved ? .authorizationApproved : .authorizationNeeded
    }

    func revokeAuthorization() async {
        do {
            try await authorizationClient.revokeAuthorization()
            let mapped = currentAuthorizationState
            reduce(.authorizationObserved(mapped))
            if mapped == .approved {
                reduce(.commandRejected(code: "authorization_revoke_not_observed"))
                message = .recoveryNeeded
            } else {
                message = .authorizationRevoked
            }
        } catch {
            reduce(.authorizationObserved(currentAuthorizationState))
            reduce(.commandRejected(code: "authorization_revoke_failed"))
            message = .recoveryNeeded
        }
    }

    func observeAuthorization() {
        let mapped = currentAuthorizationState
        reduce(.authorizationObserved(mapped))
        if mapped != .approved {
            message = .authorizationNeeded
        }
    }

    private var currentAuthorizationState: P0AuthorizationState {
#if DEBUG && targetEnvironment(simulator)
        if simulatorClosureDemoEnabled {
            return ProcessInfo.processInfo.arguments.contains("--p0-simulator-authorization=denied")
                ? .denied : .approved
        }
#endif
        return switch authorizationClient.status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .approved, .approvedWithDataAccess: .approved
        @unknown default: .notDetermined
        }
    }

    func selectionChanged() {
        if simulatorClosureDemoEnabled {
            reduce(.selectionUpdated(count: simulatorClosureSelectionCount))
            message = .selectionSaved
            return
        }
        do {
            try selectionStore.save(selection)
            reduce(.selectionUpdated(count: selectedItemCount))
            message = .selectionSaved
        } catch {
            reduce(.commandRejected(code: "selection_store_unavailable"))
            message = .recoveryNeeded
        }
    }

    func requestProtection() {
        reduce(.commandRequested(.apply, at: Date()))
    }

    func requestProtectionRemoval() {
        reduce(.commandRequested(.clear, at: Date()))
    }

    func requestProtectionRestoration() {
        reduce(.commandRequested(.reapply, at: Date()))
    }

    func clearAllLocalData() {
        _ = shieldClient.dispatch(
            kind: .clear,
            selection: selection,
            sessionID: state.sessionID,
            generation: state.generation + 1,
            requestedAt: Date()
        )
        selection = FamilyActivitySelection()
        latestIntentContext = nil
        latestIntentRecordID = nil
        state = .initial()
        state.authorization = currentAuthorizationState
        message = state.authorization == .approved ? .ready : .authorizationNeeded

        for key in [
            AppGroupKeys.activitySelection,
            AppGroupKeys.sessionSnapshot,
            AppGroupKeys.pendingShieldIntent,
            AppGroupKeys.monitorEvent,
            AppGroupKeys.focusDeadlineMonitor,
            AppGroupKeys.commandReceipt,
            AppGroupKeys.shieldCompanionSpecies,
        ] {
            appGroupStore?.removeValue(forKey: key)
        }
    }

    func reconcileAfterActivation() {
        observeAuthorization()
        do {
            guard let intent = try inboxReader.nextConsumableIntent(
                at: Date(),
                sessionID: state.sessionID,
                generation: state.generation,
                lastConsumedIntentID: state.lastConsumedIntentID
            ) else {
                return
            }
            latestIntentContext = intent.payload.context
            latestIntentRecordID = intent.recordID
            reduce(.shieldIntentConsumed(recordID: intent.recordID))
            message = .shieldRequestReceived
        } catch {
            reduce(.commandRejected(code: "intent_inbox_unavailable"))
            message = .recoveryNeeded
        }
    }

    private func reduce(_ event: P0CapabilityEvent) {
        let reduction = P0CapabilityReducer.reduce(state: state, event: event)
        state = reduction.state

        for effect in reduction.effects {
            switch effect {
            case .dispatchShieldCommand(let kind, let generation, let requestedAt):
                let receipt: ShieldCommandReceipt
                if simulatorClosureDemoEnabled {
                    let failure = ProcessInfo.processInfo.arguments.first {
                        $0 == "--p0-simulator-relock=failed" || $0 == "--p0-simulator-relock=unknown"
                    }
                    receipt = ShieldCommandReceipt(
                        commandID: UUID(), sessionID: state.sessionID, generation: generation,
                        kind: kind, requestedAt: requestedAt,
                        localDispatch: failure == nil ? .invoked : .preconditionRejected,
                        preconditionErrorCode: failure == "--p0-simulator-relock=failed"
                            ? "simulator_relock_failed"
                            : (failure == "--p0-simulator-relock=unknown" ? "simulator_relock_unknown" : nil)
                    )
                } else {
                    receipt = shieldClient.dispatch(
                        kind: kind,
                        selection: selection,
                        sessionID: state.sessionID,
                        generation: generation,
                        requestedAt: requestedAt
                    )
                }
                state = P0CapabilityReducer.reduce(
                    state: state,
                    event: .commandDispatched(receipt)
                ).state
                persistSnapshot()
                try? appGroupStore?.write(receipt, forKey: AppGroupKeys.commandReceipt)
                message = .localCommandDispatched(kind)

            case .persistSnapshot:
                persistSnapshot()
            }
        }
    }

    private func persistSnapshot() {
        let snapshot = P0SessionSnapshot(
            sessionID: state.sessionID,
            generation: state.generation,
            phase: state.phase,
            selectedItemCount: state.selectedItemCount,
            lastConsumedIntentID: state.lastConsumedIntentID,
            lastCommandReceipt: state.lastCommandReceipt,
            updatedAt: Date()
        )
        try? appGroupStore?.write(snapshot, forKey: AppGroupKeys.sessionSnapshot)
    }
}

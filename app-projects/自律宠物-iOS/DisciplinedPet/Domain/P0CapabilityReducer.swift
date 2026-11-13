import Foundation

nonisolated enum P0AuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined
    case denied
    case approved
}

nonisolated enum P0CapabilityEvent: Equatable, Sendable {
    case authorizationObserved(P0AuthorizationState)
    case authorizationRestored(sessionID: UUID)
    case selectionUpdated(count: Int)
    case commandRequested(ShieldCommandKind, at: Date)
    case commandDispatched(ShieldCommandReceipt)
    case commandRejected(code: String)
    case shieldIntentConsumed(recordID: UUID)
}

nonisolated enum P0CapabilityEffect: Equatable, Sendable {
    case dispatchShieldCommand(kind: ShieldCommandKind, generation: Int, requestedAt: Date)
    case persistSnapshot
}

nonisolated struct P0CapabilityReduction: Equatable, Sendable {
    let state: P0CapabilityState
    let effects: [P0CapabilityEffect]
}

nonisolated struct P0CapabilityState: Codable, Equatable, Sendable {
    var sessionID: UUID
    var generation: Int
    var phase: P0SessionPhase
    var authorization: P0AuthorizationState
    var selectedItemCount: Int
    var lastConsumedIntentID: UUID?
    var lastCommandReceipt: ShieldCommandReceipt?
    var latestErrorCode: String?

    static func initial(sessionID: UUID = UUID()) -> Self {
        Self(
            sessionID: sessionID,
            generation: 0,
            phase: .idle,
            authorization: .notDetermined,
            selectedItemCount: 0,
            lastConsumedIntentID: nil,
            lastCommandReceipt: nil,
            latestErrorCode: nil
        )
    }
}

nonisolated enum P0CapabilityReducer {
    static func reduce(state: P0CapabilityState, event: P0CapabilityEvent) -> P0CapabilityReduction {
        var next = state

        switch event {
        case .authorizationObserved(let authorization):
            next.authorization = authorization
            next.latestErrorCode = nil
            if authorization != .approved, next.phase == .localProtectionRequested {
                next.phase = .recoveryRequired
            }
            return .init(state: next, effects: [.persistSnapshot])

        case .authorizationRestored(let sessionID):
            next.sessionID = sessionID
            next.generation = 0
            next.phase = next.selectedItemCount > 0 ? .configuring : .idle
            next.authorization = .approved
            next.lastConsumedIntentID = nil
            next.lastCommandReceipt = nil
            next.latestErrorCode = nil
            return .init(state: next, effects: [.persistSnapshot])

        case .selectionUpdated(let count):
            next.selectedItemCount = max(0, count)
            next.phase = .configuring
            next.latestErrorCode = nil
            return .init(state: next, effects: [.persistSnapshot])

        case .commandRequested(let kind, let requestedAt):
            guard next.authorization == .approved else {
                next.latestErrorCode = "authorization_required"
                next.phase = .recoveryRequired
                return .init(state: next, effects: [.persistSnapshot])
            }
            if kind != .clear, next.selectedItemCount == 0 {
                next.latestErrorCode = "selection_required"
                return .init(state: next, effects: [.persistSnapshot])
            }
            next.generation += 1
            next.latestErrorCode = nil
            return .init(
                state: next,
                effects: [
                    .dispatchShieldCommand(
                        kind: kind,
                        generation: next.generation,
                        requestedAt: requestedAt
                    )
                ]
            )

        case .commandDispatched(let receipt):
            guard receipt.sessionID == next.sessionID, receipt.generation == next.generation else {
                next.latestErrorCode = "stale_command_receipt"
                return .init(state: next, effects: [.persistSnapshot])
            }
            next.lastCommandReceipt = receipt
            next.phase = receipt.localDispatch == .invoked ? .localProtectionRequested : .recoveryRequired
            next.latestErrorCode = receipt.preconditionErrorCode
            return .init(state: next, effects: [.persistSnapshot])

        case .commandRejected(let code):
            next.latestErrorCode = code
            next.phase = .recoveryRequired
            return .init(state: next, effects: [.persistSnapshot])

        case .shieldIntentConsumed(let recordID):
            guard next.lastConsumedIntentID != recordID else {
                return .init(state: next, effects: [])
            }
            next.lastConsumedIntentID = recordID
            return .init(state: next, effects: [.persistSnapshot])
        }
    }
}

import Foundation
import Testing
@testable import DisciplinedPet

@Suite("P0 capability reducer")
struct P0CapabilityReducerTests {
    @Test("Protection request requires authorization")
    func protectionRequiresAuthorization() {
        let initial = P0CapabilityState.initial(sessionID: UUID())
        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .commandRequested(.apply, at: Date(timeIntervalSince1970: 100))
        )

        #expect(result.state.phase == .recoveryRequired)
        #expect(result.state.latestErrorCode == "authorization_required")
        #expect(result.effects == [.persistSnapshot])
    }

    @Test("Protection request requires a selection")
    func protectionRequiresSelection() {
        var initial = P0CapabilityState.initial(sessionID: UUID())
        initial.authorization = .approved

        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .commandRequested(.apply, at: Date(timeIntervalSince1970: 100))
        )

        #expect(result.state.generation == 0)
        #expect(result.state.latestErrorCode == "selection_required")
        #expect(result.effects == [.persistSnapshot])
    }

    @Test("Valid requests increment generation", arguments: [
        ShieldCommandKind.apply,
        ShieldCommandKind.clear,
        ShieldCommandKind.reapply,
    ])
    func validRequestIncrementsGeneration(kind: ShieldCommandKind) {
        var initial = P0CapabilityState.initial(sessionID: UUID())
        initial.authorization = .approved
        initial.selectedItemCount = 2
        let requestedAt = Date(timeIntervalSince1970: 100)

        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .commandRequested(kind, at: requestedAt)
        )

        #expect(result.state.generation == 1)
        #expect(result.effects == [
            .dispatchShieldCommand(kind: kind, generation: 1, requestedAt: requestedAt)
        ])
    }

    @Test("Stale command receipt is rejected")
    func staleReceiptIsRejected() {
        var initial = P0CapabilityState.initial(sessionID: UUID())
        initial.authorization = .approved
        initial.selectedItemCount = 1
        initial.generation = 2
        let receipt = ShieldCommandReceipt(
            commandID: UUID(),
            sessionID: initial.sessionID,
            generation: 1,
            kind: .apply,
            requestedAt: Date(timeIntervalSince1970: 100),
            localDispatch: .invoked,
            preconditionErrorCode: nil
        )

        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .commandDispatched(receipt)
        )

        #expect(result.state.latestErrorCode == "stale_command_receipt")
        #expect(result.state.lastCommandReceipt == nil)
    }

    @Test("Authorization loss never preserves a local protection claim")
    func authorizationLossMovesToRecovery() {
        var initial = P0CapabilityState.initial(sessionID: UUID())
        initial.authorization = .approved
        initial.phase = .localProtectionRequested

        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .authorizationObserved(.denied)
        )

        #expect(result.state.phase == .recoveryRequired)
        #expect(result.state.authorization == .denied)
    }

    @Test("Reauthorization starts a new clean session without restoring the old claim")
    func reauthorizationStartsCleanSession() {
        let oldSessionID = UUID()
        let oldIntentID = UUID()
        var initial = P0CapabilityState.initial(sessionID: oldSessionID)
        initial.authorization = .denied
        initial.phase = .recoveryRequired
        initial.selectedItemCount = 1
        initial.generation = 8
        initial.lastConsumedIntentID = oldIntentID
        initial.lastCommandReceipt = ShieldCommandReceipt(
            commandID: UUID(),
            sessionID: oldSessionID,
            generation: 8,
            kind: .apply,
            requestedAt: Date(timeIntervalSince1970: 100),
            localDispatch: .invoked,
            preconditionErrorCode: nil
        )

        let newSessionID = UUID()
        let result = P0CapabilityReducer.reduce(
            state: initial,
            event: .authorizationRestored(sessionID: newSessionID)
        )

        #expect(result.state.sessionID == newSessionID)
        #expect(result.state.sessionID != oldSessionID)
        #expect(result.state.authorization == .approved)
        #expect(result.state.phase == .configuring)
        #expect(result.state.selectedItemCount == 1)
        #expect(result.state.generation == 0)
        #expect(result.state.lastConsumedIntentID == nil)
        #expect(result.state.lastCommandReceipt == nil)
        #expect(result.state.latestErrorCode == nil)
        #expect(result.effects == [.persistSnapshot])
    }

    @Test("authorizationObserved 后收到 commandRejected 时保留授权状态与错误码")
    func authorizationObservedThenCommandRejectedPreservesAuthorizationAndErrorCode() {
        let observed = P0CapabilityReducer.reduce(
            state: .initial(sessionID: UUID()),
            event: .authorizationObserved(.denied)
        ).state

        let result = P0CapabilityReducer.reduce(
            state: observed,
            event: .commandRejected(code: "authorization_request_failed")
        )

        #expect(result.state.authorization == .denied)
        #expect(result.state.latestErrorCode == "authorization_request_failed")
        #expect(result.state.phase == .recoveryRequired)
    }
}

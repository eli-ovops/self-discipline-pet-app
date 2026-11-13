import Foundation
import Testing
@testable import DisciplinedPet

@Suite("Shared envelope")
struct SharedEnvelopeTests {
    @Test("Only the matching unconsumed generation is consumable")
    func validatesIdentityGenerationAndConsumption() {
        let sessionID = UUID()
        let recordID = UUID()
        let now = Date(timeIntervalSince1970: 100)
        let envelope = SharedEnvelope(
            recordID: recordID,
            sessionID: sessionID,
            generation: 4,
            createdAt: now,
            expiresAt: now.addingTimeInterval(60),
            payload: PendingShieldIntent(context: .application)
        )

        #expect(envelope.isConsumable(
            at: now,
            expectedSessionID: sessionID,
            expectedGeneration: 4,
            lastConsumedRecordID: nil
        ))
        #expect(!envelope.isConsumable(
            at: now,
            expectedSessionID: sessionID,
            expectedGeneration: 3,
            lastConsumedRecordID: nil
        ))
        #expect(!envelope.isConsumable(
            at: now,
            expectedSessionID: sessionID,
            expectedGeneration: 4,
            lastConsumedRecordID: recordID
        ))
    }

    @Test("Intent expires at its deadline")
    func expiresAtDeadline() {
        let sessionID = UUID()
        let deadline = Date(timeIntervalSince1970: 160)
        let envelope = SharedEnvelope(
            sessionID: sessionID,
            generation: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            expiresAt: deadline,
            payload: PendingShieldIntent(context: .category)
        )

        #expect(!envelope.isConsumable(
            at: deadline,
            expectedSessionID: sessionID,
            expectedGeneration: 1,
            lastConsumedRecordID: nil
        ))
    }

    @Test("Envelope round trips through Codable")
    func codableRoundTrip() throws {
        let envelope = SharedEnvelope(
            sessionID: UUID(),
            generation: 2,
            createdAt: Date(timeIntervalSince1970: 100),
            expiresAt: Date(timeIntervalSince1970: 160),
            payload: PendingShieldIntent(context: .webDomain)
        )

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(
            SharedEnvelope<PendingShieldIntent>.self,
            from: data
        )

        #expect(decoded == envelope)
    }
}

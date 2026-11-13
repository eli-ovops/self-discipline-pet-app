import Foundation

nonisolated struct SharedEnvelope<Payload>: Codable, Equatable, Sendable
where Payload: Codable & Equatable & Sendable {
    static var currentSchemaVersion: Int { 1 }

    let schemaVersion: Int
    let recordID: UUID
    let sessionID: UUID
    let generation: Int
    let createdAt: Date
    let expiresAt: Date?
    let payload: Payload

    init(
        recordID: UUID = UUID(),
        sessionID: UUID,
        generation: Int,
        createdAt: Date,
        expiresAt: Date? = nil,
        payload: Payload
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.recordID = recordID
        self.sessionID = sessionID
        self.generation = generation
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.payload = payload
    }

    func isConsumable(
        at date: Date,
        expectedSessionID: UUID,
        expectedGeneration: Int,
        lastConsumedRecordID: UUID?
    ) -> Bool {
        guard schemaVersion == Self.currentSchemaVersion else { return false }
        guard sessionID == expectedSessionID else { return false }
        guard generation == expectedGeneration else { return false }
        guard recordID != lastConsumedRecordID else { return false }
        guard expiresAt.map({ date < $0 }) ?? true else { return false }
        return true
    }
}

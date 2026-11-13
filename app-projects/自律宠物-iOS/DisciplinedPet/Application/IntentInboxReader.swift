import Foundation

@MainActor
struct IntentInboxReader {
    private let store: AppGroupStore?

    init() {
        store = try? AppGroupStore()
    }

    func nextConsumableIntent(
        at date: Date,
        sessionID: UUID,
        generation: Int,
        lastConsumedIntentID: UUID?
    ) throws -> SharedEnvelope<PendingShieldIntent>? {
        guard let store else { throw AppGroupStoreError.suiteUnavailable }
        guard let intent = try store.read(
            SharedEnvelope<PendingShieldIntent>.self,
            forKey: AppGroupKeys.pendingShieldIntent
        ) else {
            return nil
        }
        guard intent.isConsumable(
            at: date,
            expectedSessionID: sessionID,
            expectedGeneration: generation,
            lastConsumedRecordID: lastConsumedIntentID
        ) else {
            return nil
        }
        return intent
    }
}

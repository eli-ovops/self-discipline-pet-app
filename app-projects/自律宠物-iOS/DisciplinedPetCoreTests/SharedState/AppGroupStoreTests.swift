import Foundation
import Testing
@testable import DisciplinedPet

@Suite("App Group store")
struct AppGroupStoreTests {
    @Test("Store round trips an isolated value")
    func roundTripsValue() throws {
        let suiteName = "DisciplinedPetCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppGroupStore(defaults: defaults)
        let snapshot = P0SessionSnapshot(
            sessionID: UUID(),
            generation: 3,
            phase: .configuring,
            selectedItemCount: 2,
            lastConsumedIntentID: nil,
            lastCommandReceipt: nil,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(snapshot, forKey: AppGroupKeys.sessionSnapshot)
        let decoded = try store.read(P0SessionSnapshot.self, forKey: AppGroupKeys.sessionSnapshot)

        #expect(decoded == snapshot)
    }

    @Test("Corrupted data is rejected")
    func corruptedDataIsRejected() throws {
        let suiteName = "DisciplinedPetCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data([0x00, 0x01]), forKey: AppGroupKeys.sessionSnapshot)

        let store = AppGroupStore(defaults: defaults)

        #expect(throws: AppGroupStoreError.decodingFailed) {
            try store.read(P0SessionSnapshot.self, forKey: AppGroupKeys.sessionSnapshot)
        }
    }
}

import Foundation
import Testing
@testable import DisciplinedPet

@Suite("Beta validation store")
struct BetaValidationStoreTests {
    @Test("Custom prices are reduced to anonymous buckets")
    func customPriceBuckets() {
        #expect(BetaValidationPriceBucket.customBucket(forUSD: 0) == .free)
        #expect(BetaValidationPriceBucket.customBucket(forUSD: 0.5) == .customUnder099)
        #expect(BetaValidationPriceBucket.customBucket(forUSD: 2.99) == .custom200To299)
        #expect(BetaValidationPriceBucket.customBucket(forUSD: 10) == .custom1000OrMore)
        #expect(BetaValidationPriceBucket.customBucket(forUSD: 1_000) == nil)
    }

    @Test("Store round trips an anonymous test ID and allowlisted event")
    @MainActor
    func roundTripsAllowlistedState() throws {
        let suiteName = "BetaValidationStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = BetaValidationStore(defaults: defaults)
        var state = BetaValidationState.fresh(testID: .init(value: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        state.append(.focusStarted(duration: 30 * 60, entrySource: .directAppOpen, at: .distantPast))

        store.save(state)

        #expect(store.loadState() == .loaded(state))
    }

    @Test("Corrupted validation data requires an explicit recovery decision")
    @MainActor
    func corruptedStateRequiresRecovery() throws {
        let suiteName = "BetaValidationStoreCorruptTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "beta-validation.state.v1")

        #expect(BetaValidationStore(defaults: defaults).loadState() == .recoveryRequired)
    }

    @Test("State keeps event identifiers unique and bounds local storage")
    func stateDeduplicatesAndBoundsEvents() {
        var state = BetaValidationState.fresh()
        let duplicate = BetaValidationEvent(id: UUID(), kind: .firstEntered, occurredAt: .distantPast)
        state.append(duplicate)
        state.append(duplicate)
        #expect(state.events.count == 1)

        for index in 0...BetaValidationState.maximumEventCount {
            state.append(.init(kind: .focusStarted, occurredAt: Date(timeIntervalSince1970: TimeInterval(index))))
        }
        #expect(state.events.count == BetaValidationState.maximumEventCount)
    }

    @Test("Store normalizes an oversized but valid loaded payload")
    @MainActor
    func storeNormalizesOversizedPayload() throws {
        let suiteName = "BetaValidationStoreOversizedTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var state = BetaValidationState.fresh()
        state.events = (0...BetaValidationState.maximumEventCount).map { index in
            .init(kind: .focusStarted, occurredAt: Date(timeIntervalSince1970: TimeInterval(index)))
        }
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: "beta-validation.state.v1")

        let result = BetaValidationStore(defaults: defaults).loadState()
        let loaded = try #require(result.loadedState)
        #expect(loaded.events.count == BetaValidationState.maximumEventCount)
        #expect(loaded.events.first?.occurredAt == Date(timeIntervalSince1970: 1))
    }
}

private extension BetaValidationStoreLoadResult {
    var loadedState: BetaValidationState? {
        guard case .loaded(let state) = self else { return nil }
        return state
    }
}

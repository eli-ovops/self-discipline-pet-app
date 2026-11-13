import Foundation

/// Random, installation-local identifier for a voluntarily shared Beta report.
/// It is not an account ID and must never be used for cross-app tracking.
nonisolated struct BetaValidationTestID: Codable, Equatable, Hashable, Sendable {
    let value: UUID

    init(value: UUID = UUID()) {
        self.value = value
    }
}

nonisolated enum BetaValidationEntrySource: String, Codable, Equatable, Sendable {
    case directAppOpen
    case notification
    case unknown
}

nonisolated enum BetaValidationAuthorizationOutcome: String, Codable, Equatable, Sendable {
    case approved
    case denied
    case unavailable
}

nonisolated enum BetaValidationEventKind: String, Codable, CaseIterable, Equatable, Sendable {
    case firstEntered
    case directAppOpened
    case companionAdopted
    case authorizationRequested
    case authorizationApproved
    case authorizationDenied
    case authorizationUnavailable
    case focusStarted
    case accessRequested
    case returnedToFocus
    case focusCompleted
    case focusEndedEarly
    case accessTimedOut
    case feedbackFlowOpened
    case feedbackConfirmedByUser
    case willingnessToPayAnswered
}

/// The only event payloads allowed in the local Beta validation log.
/// Never add goal text, access-reason text, app names, or a custom pet name.
nonisolated struct BetaValidationEvent: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: BetaValidationEventKind
    let occurredAt: Date
    let focusDurationSeconds: Int?
    let entrySource: BetaValidationEntrySource?

    init(
        id: UUID = UUID(),
        kind: BetaValidationEventKind,
        occurredAt: Date,
        focusDurationSeconds: Int? = nil,
        entrySource: BetaValidationEntrySource? = nil
    ) {
        self.id = id
        self.kind = kind
        self.occurredAt = occurredAt
        self.focusDurationSeconds = focusDurationSeconds.map { max(0, $0) }
        self.entrySource = entrySource
    }

    static func authorization(
        _ outcome: BetaValidationAuthorizationOutcome,
        at occurredAt: Date
    ) -> Self {
        let kind: BetaValidationEventKind = switch outcome {
        case .approved: .authorizationApproved
        case .denied: .authorizationDenied
        case .unavailable: .authorizationUnavailable
        }
        return .init(kind: kind, occurredAt: occurredAt)
    }

    static func focusStarted(
        duration: TimeInterval,
        entrySource: BetaValidationEntrySource,
        at occurredAt: Date
    ) -> Self {
        .init(
            kind: .focusStarted,
            occurredAt: occurredAt,
            focusDurationSeconds: Int(duration.rounded()),
            entrySource: entrySource
        )
    }

    static func focusCompleted(duration: TimeInterval, at occurredAt: Date) -> Self {
        .init(
            kind: .focusCompleted,
            occurredAt: occurredAt,
            focusDurationSeconds: Int(duration.rounded())
        )
    }
}

nonisolated enum BetaValidationPurchaseIntent: String, Codable, CaseIterable, Equatable, Sendable {
    case wouldBuy
    case mightBuy
    case unsure
    case freeOnly
    case wouldNotBuy
}

nonisolated enum BetaValidationProductUnderstanding: String, Codable, CaseIterable, Equatable, Sendable {
    case companionAndBlocking
    case companionOnly
    case blockerOnly
    case unclear
}

nonisolated enum BetaValidationOwnershipDesire: String, Codable, CaseIterable, Equatable, Sendable {
    case wantToKeep
    case interested
    case neutral
    case notForMe
}

nonisolated enum BetaValidationPurchaseDriver: String, Codable, CaseIterable, Equatable, Sendable {
    case companion
    case appBlocking
    case visualPolish
    case liveActivity
    case none
}

nonisolated enum BetaValidationPriceBucket: String, Codable, CaseIterable, Equatable, Sendable {
    case free
    case usd099
    case usd199
    case usd299
    case usd499
    case usd999
    case customUnder099
    case custom100To199
    case custom200To299
    case custom300To499
    case custom500To999
    case custom1000OrMore

    static func customBucket(forUSD value: Decimal) -> Self? {
        guard value >= 0, value <= 999 else { return nil }
        switch value {
        case 0: return .free
        case ..<1: return .customUnder099
        case ..<2: return .custom100To199
        case ..<3: return .custom200To299
        case ..<5: return .custom300To499
        case ..<10: return .custom500To999
        default: return .custom1000OrMore
        }
    }
}

nonisolated struct BetaValidationWTPResponse: Codable, Equatable, Sendable {
    let productUnderstanding: BetaValidationProductUnderstanding?
    let ownershipDesire: BetaValidationOwnershipDesire?
    let purchaseDriver: BetaValidationPurchaseDriver?
    let intent: BetaValidationPurchaseIntent
    let selectedPrice: BetaValidationPriceBucket?
    let customPriceBucket: BetaValidationPriceBucket?
    let answeredAt: Date

    init(
        productUnderstanding: BetaValidationProductUnderstanding? = nil,
        ownershipDesire: BetaValidationOwnershipDesire? = nil,
        purchaseDriver: BetaValidationPurchaseDriver? = nil,
        intent: BetaValidationPurchaseIntent,
        selectedPrice: BetaValidationPriceBucket?,
        customPriceBucket: BetaValidationPriceBucket? = nil,
        answeredAt: Date
    ) {
        self.productUnderstanding = productUnderstanding
        self.ownershipDesire = ownershipDesire
        self.purchaseDriver = purchaseDriver
        self.intent = intent
        self.selectedPrice = selectedPrice
        self.customPriceBucket = customPriceBucket
        self.answeredAt = answeredAt
    }
}

nonisolated enum BetaValidationWTPState: Codable, Equatable, Sendable {
    case notPresented
    case dismissed(at: Date)
    case answered(BetaValidationWTPResponse)

    var isFinal: Bool {
        switch self {
        case .notPresented: false
        case .dismissed, .answered: true
        }
    }
}

nonisolated struct BetaValidationState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumEventCount = 500

    var schemaVersion: Int
    let testID: BetaValidationTestID
    var events: [BetaValidationEvent]
    var willingnessToPay: BetaValidationWTPState

    static func fresh(testID: BetaValidationTestID = .init()) -> Self {
        .init(
            schemaVersion: currentSchemaVersion,
            testID: testID,
            events: [],
            willingnessToPay: .notPresented
        )
    }

    mutating func append(_ event: BetaValidationEvent) {
        guard !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count - Self.maximumEventCount)
        }
    }

    mutating func normalizeLoadedEventLimit() {
        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count - Self.maximumEventCount)
        }
    }

    mutating func recordWillingnessToPay(_ response: BetaValidationWTPResponse) {
        guard !willingnessToPay.isFinal else { return }
        willingnessToPay = .answered(response)
        append(.init(kind: .willingnessToPayAnswered, occurredAt: response.answeredAt))
    }

    mutating func dismissWillingnessToPay(at date: Date) {
        guard !willingnessToPay.isFinal else { return }
        willingnessToPay = .dismissed(at: date)
    }
}

nonisolated struct BetaValidationFunnel: Codable, Equatable, Sendable {
    let firstEntered: Int
    let companionAdopted: Int
    let authorizationApproved: Int
    let focusStarted: Int
    let focusCompleted: Int
}

nonisolated struct BetaValidationP2Summary: Codable, Equatable, Sendable {
    let firstEffectiveCompletionAt: Date?
    let d2DirectReuseCount: Int
    let d7DirectReuseCount: Int
}

nonisolated struct BetaValidationReport: Codable, Equatable, Sendable {
    static let formatVersion = 1

    let formatVersion: Int
    let testID: BetaValidationTestID
    let generatedAt: Date
    let eventCounts: [BetaValidationEventKind: Int]
    let funnel: BetaValidationFunnel
    let p2: BetaValidationP2Summary
    let willingnessToPay: BetaValidationWTPState
}

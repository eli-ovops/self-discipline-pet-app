import Foundation

nonisolated enum BetaValidationReportBuilder {
    static let minimumEffectiveFocusDuration: TimeInterval = 30 * 60

    static func build(
        from state: BetaValidationState,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> BetaValidationReport {
        let counts = Dictionary(
            grouping: state.events,
            by: \.kind
        ).mapValues(\.count)

        let firstEffectiveCompletion = state.events
            .filter { event in
                event.kind == .focusCompleted
                    && (event.focusDurationSeconds ?? 0) >= Int(minimumEffectiveFocusDuration)
            }
            .map(\.occurredAt)
            .min()
        let generatedDay = calendar.startOfDay(for: generatedAt)
        let firstEffectiveCompletionDay = firstEffectiveCompletion.map {
            calendar.startOfDay(for: $0)
        }

        return .init(
            formatVersion: BetaValidationReport.formatVersion,
            testID: state.testID,
            generatedAt: generatedDay,
            eventCounts: counts,
            funnel: .init(
                firstEntered: counts[.firstEntered, default: 0],
                companionAdopted: counts[.companionAdopted, default: 0],
                authorizationApproved: counts[.authorizationApproved, default: 0],
                focusStarted: counts[.focusStarted, default: 0],
                focusCompleted: counts[.focusCompleted, default: 0]
            ),
            p2: .init(
                firstEffectiveCompletionAt: firstEffectiveCompletionDay,
                d2DirectReuseCount: reuseCount(
                    in: state.events,
                    daysAfter: 2,
                    firstEffectiveCompletion: firstEffectiveCompletion,
                    calendar: calendar
                ),
                d7DirectReuseCount: reuseCount(
                    in: state.events,
                    daysAfter: 7,
                    firstEffectiveCompletion: firstEffectiveCompletion,
                    calendar: calendar
                )
            ),
            willingnessToPay: dayNormalizedWillingnessToPay(
                state.willingnessToPay,
                calendar: calendar
            )
        )
    }

    static func jsonData(for report: BetaValidationReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    private static func reuseCount(
        in events: [BetaValidationEvent],
        daysAfter: Int,
        firstEffectiveCompletion: Date?,
        calendar: Calendar
    ) -> Int {
        guard let firstEffectiveCompletion,
              let targetDay = calendar.date(
                byAdding: .day,
                value: daysAfter,
                to: calendar.startOfDay(for: firstEffectiveCompletion)
              ) else {
            return 0
        }
        return events.filter { event in
            guard event.kind == .focusStarted else {
                return false
            }
            return calendar.isDate(event.occurredAt, inSameDayAs: targetDay)
        }.count
    }

    private static func dayNormalizedWillingnessToPay(
        _ state: BetaValidationWTPState,
        calendar: Calendar
    ) -> BetaValidationWTPState {
        switch state {
        case .notPresented:
            return .notPresented
        case .dismissed(let date):
            return .dismissed(at: calendar.startOfDay(for: date))
        case .answered(let response):
            return .answered(.init(
                productUnderstanding: response.productUnderstanding,
                ownershipDesire: response.ownershipDesire,
                purchaseDriver: response.purchaseDriver,
                intent: response.intent,
                selectedPrice: response.selectedPrice,
                customPriceBucket: response.customPriceBucket,
                answeredAt: calendar.startOfDay(for: response.answeredAt)
            ))
        }
    }
}

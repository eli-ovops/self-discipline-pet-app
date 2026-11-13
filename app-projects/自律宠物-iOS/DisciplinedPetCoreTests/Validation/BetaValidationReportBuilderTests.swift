import Foundation
import Testing
@testable import DisciplinedPet

@Suite("Beta validation report")
struct BetaValidationReportBuilderTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("D2 and D7 count actual focus starts after an effective completion")
    func d2AndD7CountFocusStartsOnly() {
        let firstCompletion = Date(timeIntervalSince1970: 1_704_067_200)
        var state = BetaValidationState.fresh(testID: .init(value: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!))
        state.append(.focusCompleted(duration: 30 * 60, at: firstCompletion))
        state.append(.focusStarted(
            duration: 30 * 60,
            entrySource: .directAppOpen,
            at: calendar.date(byAdding: .day, value: 2, to: firstCompletion)!
        ))
        state.append(.init(
            kind: .directAppOpened,
            occurredAt: calendar.date(byAdding: .day, value: 2, to: firstCompletion)!,
            entrySource: .notification
        ))
        state.append(.focusStarted(
            duration: 45 * 60,
            entrySource: .directAppOpen,
            at: calendar.date(byAdding: .day, value: 7, to: firstCompletion)!
        ))

        let report = BetaValidationReportBuilder.build(
            from: state,
            generatedAt: firstCompletion,
            calendar: calendar
        )

        #expect(report.p2.firstEffectiveCompletionAt == calendar.startOfDay(for: firstCompletion))
        #expect(report.p2.d2DirectReuseCount == 1)
        #expect(report.p2.d7DirectReuseCount == 1)
    }

    @Test("A sub-threshold completion does not create a D2 or D7 cohort")
    func shortCompletionDoesNotStartReuseCohort() {
        var state = BetaValidationState.fresh()
        state.append(.focusCompleted(duration: 20 * 60, at: .distantPast))
        state.append(.focusStarted(duration: 30 * 60, entrySource: .directAppOpen, at: Date()))

        let report = BetaValidationReportBuilder.build(from: state, calendar: calendar)

        #expect(report.p2.firstEffectiveCompletionAt == nil)
        #expect(report.p2.d2DirectReuseCount == 0)
        #expect(report.p2.d7DirectReuseCount == 0)
    }

    @Test("WTP is one-time, discrete, and its report contains no free-text fields")
    func wtpIsOneTimeAndReportIsDeidentified() throws {
        let answeredAt = Date(timeIntervalSince1970: 1_704_067_200)
        var state = BetaValidationState.fresh()
        state.recordWillingnessToPay(.init(
            intent: .mightBuy,
            selectedPrice: .usd299,
            customPriceBucket: .custom200To299,
            answeredAt: answeredAt
        ))
        state.recordWillingnessToPay(.init(
            intent: .wouldBuy,
            selectedPrice: .usd999,
            answeredAt: answeredAt.addingTimeInterval(1)
        ))
        let report = BetaValidationReportBuilder.build(from: state, generatedAt: answeredAt, calendar: calendar)
        let json = try String(decoding: BetaValidationReportBuilder.jsonData(for: report), as: UTF8.self)

        #expect(report.willingnessToPay == .answered(.init(
            intent: .mightBuy,
            selectedPrice: .usd299,
            customPriceBucket: .custom200To299,
            answeredAt: calendar.startOfDay(for: answeredAt)
        )))
        #expect(report.eventCounts[.willingnessToPayAnswered] == 1)
        #expect(json.contains("goal") == false)
        #expect(json.contains("reason") == false)
        #expect(json.contains("petName") == false)
        #expect(json.contains("appName") == false)
        #expect(json.contains("Finish chapter") == false)
        #expect(json.contains("verification code") == false)
        #expect(json.contains("TikTok") == false)
        #expect(json.contains("Milo") == false)
    }

    @Test("A dismissed price question is final and does not fabricate a response")
    func dismissedQuestionIsFinal() {
        var state = BetaValidationState.fresh()
        state.dismissWillingnessToPay(at: .distantPast)
        state.recordWillingnessToPay(.init(
            intent: .wouldBuy,
            selectedPrice: .usd299,
            answeredAt: Date()
        ))

        #expect(state.willingnessToPay == .dismissed(at: .distantPast))
        #expect(state.events.contains(where: { $0.kind == .willingnessToPayAnswered }) == false)
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            FocusLiveActivityLockScreenView(state: context.state)
                // Lock Screen tint is app-controlled; Dynamic Island's black
                // opaque surface is controlled by iOS and intentionally untouched.
                .activityBackgroundTint(Color.focumiPaper)
                .activitySystemActionForegroundColor(Color.focumiCoral)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusLiveActivityPetBadge(
                        pet: context.state.pet,
                        phase: context.state.phase,
                        size: 58
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    FocusLiveActivityTimerView(deadline: context.state.deadline, prominence: .expanded)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    FocusLiveActivityExpandedDetailsView(state: context.state)
                }
            } compactLeading: {
                FocusLiveActivityPetGlyph(
                    pet: context.state.pet,
                    phase: context.state.phase,
                    frameSize: 22
                )
            } compactTrailing: {
                FocusLiveActivityTimerView(deadline: context.state.deadline, prominence: .compact)
            } minimal: {
                FocusLiveActivityPetGlyph(
                    pet: context.state.pet,
                    phase: context.state.phase,
                    frameSize: 24
                )
            }
            // Dynamic Island's black field is controlled by iOS. Focumi only
            // controls the cream badge, concise time, and this restrained keyline.
            .keylineTint(context.state.phase.keylineColor)
        }
    }
}

#Preview("Lock Screen", as: .content, using: FocusLiveActivityAttributes(sessionID: UUID())) {
    FocusLiveActivityWidget()
} contentStates: {
    FocusLiveActivityAttributes.ContentState.previewFocusing
    FocusLiveActivityAttributes.ContentState.previewWaiting
    FocusLiveActivityAttributes.ContentState.previewReturning
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: FocusLiveActivityAttributes(sessionID: UUID())) {
    FocusLiveActivityWidget()
} contentStates: {
    FocusLiveActivityAttributes.ContentState.previewFocusing
    FocusLiveActivityAttributes.ContentState.previewWaiting
    FocusLiveActivityAttributes.ContentState.previewReturning
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: FocusLiveActivityAttributes(sessionID: UUID())) {
    FocusLiveActivityWidget()
} contentStates: {
    FocusLiveActivityAttributes.ContentState.previewFocusing
    FocusLiveActivityAttributes.ContentState.previewWaiting
    FocusLiveActivityAttributes.ContentState.previewReturning
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: FocusLiveActivityAttributes(sessionID: UUID())) {
    FocusLiveActivityWidget()
} contentStates: {
    FocusLiveActivityAttributes.ContentState.previewFocusing
    FocusLiveActivityAttributes.ContentState.previewWaiting
    FocusLiveActivityAttributes.ContentState.previewReturning
}

private extension FocusLiveActivityAttributes.ContentState {
    static let previewFocusing = Self(
        pet: .cat,
        petName: "Milo",
        goal: "Finish chapter three",
        phase: .focusing,
        deadline: .now.addingTimeInterval(45 * 60)
    )

    static let previewWaiting = Self(
        pet: .dog,
        petName: "Max",
        goal: "Review tomorrow's notes",
        phase: .waitingToReturn,
        deadline: .now.addingTimeInterval(52 * 60)
    )

    static let previewReturning = Self(
        pet: .dog,
        petName: "Max",
        goal: "Return to today's page",
        phase: .returning,
        deadline: .now.addingTimeInterval(18 * 60)
    )
}

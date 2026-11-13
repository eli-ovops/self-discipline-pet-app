import SwiftUI

struct FocusLiveActivityLockScreenView: View {
    let state: FocusLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            FocusLiveActivityPetBadge(pet: state.pet, phase: state.phase, size: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: state.goal)
                    .font(.headline)
                    .lineLimit(1)
                    .privacySensitive()

                FocusLiveActivityTimerView(deadline: state.deadline, prominence: .lockScreen)
                    .foregroundStyle(Color.focumiInk)

                Text(state.phase.statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.focumiInk.opacity(0.74))
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .foregroundStyle(Color.focumiInk)
        .accessibilityElement(children: .combine)
    }
}

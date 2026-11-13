import SwiftUI

struct FocusLiveActivityExpandedDetailsView: View {
    let state: FocusLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: state.goal)
                .font(.headline)
                .lineLimit(1)
                .privacySensitive()

            Text(state.phase.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.focumiPaper.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

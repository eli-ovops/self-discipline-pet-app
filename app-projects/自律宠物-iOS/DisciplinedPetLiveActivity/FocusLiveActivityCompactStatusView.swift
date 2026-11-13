import SwiftUI

struct FocusLiveActivityCompactStatusView: View {
    let phase: FocusLiveActivityPhase

    var body: some View {
        Text(phase.compactStatusText)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }
}

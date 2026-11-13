import SwiftUI

struct FocusLiveActivityTimerView: View {
    enum Prominence {
        case compact
        case expanded
        case lockScreen
    }

    let deadline: Date
    let prominence: Prominence

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                timerText
            } else {
                timerText.contentTransition(.numericText())
            }
        }
        .font(timerFont)
        .fontDesign(.rounded)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityLabel("Time remaining")
    }

    private var timerFont: Font {
        switch prominence {
        case .compact: .caption.bold()
        case .expanded: .title3.bold()
        case .lockScreen: .title2.bold()
        }
    }

    private var timerText: Text {
        Text(
            timerInterval: min(.now, deadline)...deadline,
            countsDown: true,
            showsHours: true
        )
    }
}

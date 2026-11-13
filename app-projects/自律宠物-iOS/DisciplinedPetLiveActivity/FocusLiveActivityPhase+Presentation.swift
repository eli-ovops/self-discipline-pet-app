import SwiftUI

extension FocusLiveActivityPhase {
    var keylineColor: Color {
        switch self {
        case .focusing: Color.focumiCoral
        case .waitingToReturn: Color(red: 132 / 255, green: 149 / 255, blue: 110 / 255)
        case .returning: Color(red: 120 / 255, green: 148 / 255, blue: 163 / 255)
        }
    }
}

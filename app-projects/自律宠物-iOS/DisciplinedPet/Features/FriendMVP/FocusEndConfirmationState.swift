import Foundation

/// A short-lived presentation state only. It neither changes the focus session
/// nor represents Managed Settings / Shield success.
nonisolated struct FocusEndConfirmationState: Equatable, Sendable {
    private(set) var isPresented: Bool

    init(isPresented: Bool = false) {
        self.isPresented = isPresented
    }

    mutating func request() {
        isPresented = true
    }

    mutating func continueFocusing() {
        isPresented = false
    }

    mutating func confirmEnd() -> Bool {
        guard isPresented else { return false }
        isPresented = false
        return true
    }
}

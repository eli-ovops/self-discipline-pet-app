import Foundation

/// Ephemeral visual accompaniment. It is derived from an already-observed UI
/// phase only and owns no session, protection, deadline, or ActivityKit truth.
nonisolated enum CompanionPerformanceState: Equatable, Sendable {
    case reopeningPage
}

nonisolated struct CompanionPerformanceCue: Equatable, Sendable {
    let token: Int
    let state: CompanionPerformanceState
}

/// Deduplicates reconciliation-driven phase observations. A cue is optional;
/// omitting it never changes the underlying focus state or CTA availability.
nonisolated struct CompanionPerformanceCoordinator: Equatable, Sendable {
    private var lastTransition: Transition?
    private(set) var nextToken = 0

    mutating func cue(
        from previous: FriendMVPPhase,
        to current: FriendMVPPhase,
        reduceMotion: Bool
    ) -> CompanionPerformanceCue? {
        let transition = Transition(previous: previous, current: current)
        guard transition != lastTransition, let state = state(for: transition) else { return nil }
        lastTransition = transition
        guard !reduceMotion else { return nil }
        nextToken += 1
        return CompanionPerformanceCue(token: nextToken, state: state)
    }

    private func state(for transition: Transition) -> CompanionPerformanceState? {
        switch (transition.previous, transition.current) {
        case (.accessWindow, .focusing): .reopeningPage
        default: nil
        }
    }

    private struct Transition: Equatable, Sendable {
        let previous: FriendMVPPhase
        let current: FriendMVPPhase
    }
}

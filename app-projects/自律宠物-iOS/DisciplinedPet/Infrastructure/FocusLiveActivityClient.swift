import ActivityKit
import Foundation

@MainActor
final class FocusLiveActivityClient {
    private var syncGeneration = 0

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func sync(
        snapshot: FriendMVPSnapshot,
        presentingReturn: Bool = false,
        now: Date = .now
    ) {
        syncGeneration += 1
        let generation = syncGeneration
        let state = FocusLiveActivityProjection.contentState(
            from: snapshot,
            presentationPhase: presentingReturn ? .returning : nil,
            now: now
        )

        Task { @MainActor [weak self] in
            guard let self, generation == syncGeneration else { return }
            await performSync(state: state, generation: generation)
        }

        guard presentingReturn else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(850))
            guard let self, generation == syncGeneration else { return }
            self.sync(snapshot: snapshot)
        }
    }

    private func performSync(
        state: FocusLiveActivityAttributes.ContentState?,
        generation: Int
    ) async {
        let activities = Activity<FocusLiveActivityAttributes>.activities

        guard let state else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let content = ActivityContent(state: state, staleDate: state.deadline)
        if let current = activities.first {
            await current.update(content)
            guard generation == syncGeneration else { return }
            for duplicate in activities.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        guard activitiesEnabled, generation == syncGeneration else { return }
        _ = try? Activity.request(
            attributes: FocusLiveActivityAttributes(sessionID: UUID()),
            content: content,
            pushType: nil
        )
    }
}

nonisolated enum FocusLiveActivityProjection {
    static func contentState(
        from snapshot: FriendMVPSnapshot,
        presentationPhase: FocusLiveActivityPhase? = nil,
        now: Date
    ) -> FocusLiveActivityAttributes.ContentState? {
        guard let pet = snapshot.pet else { return nil }

        let phase: FocusLiveActivityPhase
        let deadline: Date
        switch snapshot.phase {
        case .focusing, .requestingAccess:
            guard let focusDeadline = snapshot.focusDeadline else { return nil }
            phase = .focusing
            deadline = focusDeadline
        case .accessWindow:
            guard let accessDeadline = snapshot.accessDeadline else { return nil }
            phase = .waitingToReturn
            deadline = accessDeadline
        case .onboarding, .setup, .completed:
            return nil
        }

        guard deadline > now else { return nil }
        return FocusLiveActivityAttributes.ContentState(
            pet: pet == .cat ? .cat : .dog,
            petName: (pet == .cat ? FocusLiveActivityPet.cat : .dog)
                .presentationName(storedName: snapshot.petName),
            goal: snapshot.goal,
            phase: presentationPhase ?? phase,
            deadline: deadline
        )
    }
}

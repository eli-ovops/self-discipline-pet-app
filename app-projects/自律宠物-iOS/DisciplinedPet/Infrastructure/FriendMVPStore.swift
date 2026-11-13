import Foundation

nonisolated enum FriendMVPStoreLoadResult: Equatable, Sendable {
    case loaded(FriendBetaPersistedState)
    case recoveryRequired
}

@MainActor
final class FriendMVPStore {
    private let defaults: UserDefaults
    private let legacySnapshotKey = "friend-mvp.snapshot.v1"
    private let stateKey = "friend-beta.state.v2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadState() -> FriendMVPStoreLoadResult {
#if DEBUG
        if let preview = previewSnapshot() {
            return .loaded(.init(snapshot: preview, preferences: previewPreferences()))
        }
#endif
        if defaults.object(forKey: stateKey) != nil {
            guard let data = defaults.data(forKey: stateKey),
                  let state = try? decoder.decode(FriendBetaPersistedState.self, from: data) else {
                return .recoveryRequired
            }
            return .loaded(normalized(state))
        }

        if defaults.object(forKey: legacySnapshotKey) != nil {
            guard let data = defaults.data(forKey: legacySnapshotKey),
                  let snapshot = try? decoder.decode(FriendMVPSnapshot.self, from: data) else {
                return .recoveryRequired
            }
            let migrated = FriendBetaPersistedState(
                snapshot: snapshot,
                preferences: migratedPreferences(from: snapshot)
            )
            save(migrated)
            return .loaded(migrated)
        }

        return .loaded(.init(snapshot: .fresh(), preferences: .fresh()))
    }

    func save(_ state: FriendBetaPersistedState) {
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: stateKey)
    }

    func clearAllLocalData() {
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: legacySnapshotKey)
    }

    private func migratedPreferences(from snapshot: FriendMVPSnapshot) -> FriendBetaPreferences {
        var preferences = FriendBetaPreferences.fresh()
        if FriendBetaPreferences.supportedFocusDurations.contains(snapshot.plannedFocusDuration) {
            preferences.preferredFocusDuration = snapshot.plannedFocusDuration
        }
        preferences.currentPetFocusedDuration = TimeInterval(snapshot.completedSessions)
            * max(0, snapshot.plannedFocusDuration)
        return preferences
    }

    private func normalized(_ state: FriendBetaPersistedState) -> FriendBetaPersistedState {
        var next = state
        if !FriendBetaPreferences.supportedFocusDurations.contains(
            next.preferences.preferredFocusDuration
        ) {
            next.preferences.preferredFocusDuration = 30 * 60
        }
        next.preferences.musicVolume = min(1, max(0, next.preferences.musicVolume))
        next.preferences.remainingPetChanges = min(1, max(0, next.preferences.remainingPetChanges))
        return next
    }

#if DEBUG
    private func previewPreferences() -> FriendBetaPreferences {
        // Legacy preview arguments may still be present in old QA launch
        // scripts. The single paper treatment intentionally ignores them.
        FriendBetaPreferences.fresh()
    }

    private func previewSnapshot(now: Date = Date()) -> FriendMVPSnapshot? {
        let rawPhase = (
            ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("--friend-mvp-preview=") })?
                .split(separator: "=", maxSplits: 1)
                .last
                .map(String.init)
        ) ?? ProcessInfo.processInfo.environment["FOCUMI_PREVIEW_PHASE"]

        guard let rawPhase,
              let phase = FriendMVPPhase(rawValue: rawPhase) else {
            return nil
        }

        let species = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--friend-mvp-preview-pet=") })?
            .split(separator: "=", maxSplits: 1)
            .last
            .flatMap { PetSpecies(rawValue: String($0)) }
            ?? ProcessInfo.processInfo.environment["FOCUMI_PREVIEW_PET"]
                .flatMap(PetSpecies.init(rawValue:))
            ?? .cat

        var snapshot = FriendMVPSnapshot.fresh(now: now)
        snapshot.pet = species
        snapshot.petName = species == .cat ? "Milo" : "Max"
        snapshot.phase = phase
        snapshot.goal = "完成第三章"
        if ProcessInfo.processInfo.arguments.contains("--friend-mvp-preview-free-focus-alert")
            || ProcessInfo.processInfo.arguments.contains("--friend-mvp-preview-empty-goal") {
            snapshot.goal = ""
        }
        snapshot.plannedFocusDuration = 45 * 60
        snapshot.remainingFocusDuration = 32 * 60
        snapshot.completedSessions = 3
        snapshot.bondPoints = 30

        switch phase {
        case .onboarding, .setup:
            break
        case .focusing, .requestingAccess:
            snapshot.focusDeadline = now.addingTimeInterval(32 * 60)
        case .accessWindow:
            snapshot.focusDeadline = nil
            snapshot.accessWindowID = UUID()
            snapshot.accessStartedAt = now.addingTimeInterval(-12 * 60)
            snapshot.accessDeadline = now.addingTimeInterval(48 * 60)
            snapshot.accessRequestCount = 1
            snapshot.latestReason = .studyResearch
        case .completed:
            snapshot.remainingFocusDuration = 0
        }

        return snapshot
    }
#endif
}

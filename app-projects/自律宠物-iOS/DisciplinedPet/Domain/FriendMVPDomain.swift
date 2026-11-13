import Foundation

nonisolated enum PetSpecies: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case cat
    case dog

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .cat: "Milo"
        case .dog: "Max"
        }
    }
}

nonisolated enum PetMood: String, Codable, Equatable, Sendable {
    case welcome
    case focusing
    case waiting
    case celebrating
}

nonisolated enum FriendMVPPhase: String, Codable, Equatable, Sendable {
    case onboarding
    case setup
    case focusing
    case requestingAccess
    case accessWindow
    case completed
}

nonisolated enum FocusGoalMode: String, Codable, Equatable, Sendable {
    case specific
    case freeFocus
}

nonisolated enum FocusMusicTrack: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case firstLight
    case budding
    case deepBlue

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case Self.firstLight.rawValue, "gentlePiano": self = .firstLight
        case Self.budding.rawValue: self = .budding
        case Self.deepBlue.rawValue, "quietAmbient": self = .deepBlue
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown focus music track: \(value)"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct ArchivedPetMemory: Codable, Equatable, Sendable {
    let species: PetSpecies
    let name: String
    let completedSessions: Int
    let bondPoints: Int
    let focusedDuration: TimeInterval
    let archivedAt: Date
}

nonisolated struct FriendBetaPreferences: Codable, Equatable, Sendable {
    var preferredFocusDuration: TimeInterval
    var musicEnabled: Bool
    var selectedMusicTrack: FocusMusicTrack
    var musicVolume: Double
    var remainingPetChanges: Int
    var archivedPetMemory: ArchivedPetMemory?
    var currentPetFocusedDuration: TimeInterval

    static let supportedFocusDurations: [TimeInterval] = [
        30 * 60,
        45 * 60,
        60 * 60,
        120 * 60,
    ]

    static func fresh() -> Self {
        Self(
            preferredFocusDuration: 30 * 60,
            // New installs begin with the low-presence home ambience. Existing
            // persisted preferences are decoded unchanged, so a person who has
            // already turned music off is never silently opted back in.
            musicEnabled: true,
            // Home uses FirstLight. Start new focus sessions on a distinct
            // CC0 track so the default transition is immediately perceptible.
            selectedMusicTrack: .deepBlue,
            // This is a relative preference. The audio coordinator applies
            // the gentle Home/Focus program gains without replacing it.
            musicVolume: 0.85,
            remainingPetChanges: 1,
            archivedPetMemory: nil,
            currentPetFocusedDuration: 0
        )
    }
}

nonisolated struct FriendBetaPersistedState: Codable, Equatable, Sendable {
    var snapshot: FriendMVPSnapshot
    var preferences: FriendBetaPreferences
}

nonisolated enum CompanionRelationshipStage: String, CaseIterable, Equatable, Sendable {
    case firstHello
    case gettingAcquainted
    case growingTrust
    case inSync
    case lastingCompanions

    static func stage(completedSessions: Int) -> Self {
        switch max(0, completedSessions) {
        case 0: .firstHello
        case 1..<5: .gettingAcquainted
        case 5..<15: .growingTrust
        case 15..<30: .inSync
        default: .lastingCompanions
        }
    }
}

nonisolated enum AccessReasonKind: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case verificationCode
    case importantMessage
    case studyResearch
    case urgentMatter
    case custom

    var id: String { rawValue }
}

nonisolated struct FriendMVPSnapshot: Codable, Equatable, Sendable {
    var pet: PetSpecies?
    var petName: String
    var bondPoints: Int
    var completedSessions: Int
    var phase: FriendMVPPhase
    var goalMode: FocusGoalMode?
    var goal: String
    var plannedFocusDuration: TimeInterval
    var remainingFocusDuration: TimeInterval
    var focusDeadline: Date?
    var focusMonitorID: UUID?
    var accessWindowID: UUID?
    var accessStartedAt: Date?
    var accessDeadline: Date?
    var accessRequestCount: Int
    var totalAccessDuration: TimeInterval
    var latestReason: AccessReasonKind?
    var remindersAvailable: Bool
    var updatedAt: Date

    static func fresh(now: Date = Date()) -> Self {
        Self(
            pet: nil,
            petName: "",
            bondPoints: 0,
            completedSessions: 0,
            phase: .onboarding,
            goalMode: .specific,
            goal: "",
            plannedFocusDuration: 30 * 60,
            remainingFocusDuration: 30 * 60,
            focusDeadline: nil,
            focusMonitorID: nil,
            accessWindowID: nil,
            accessStartedAt: nil,
            accessDeadline: nil,
            accessRequestCount: 0,
            totalAccessDuration: 0,
            latestReason: nil,
            remindersAvailable: true,
            updatedAt: now
        )
    }
}

nonisolated enum FriendMVPEvent: Equatable, Sendable {
    case petAdopted(species: PetSpecies, name: String, at: Date)
    case petChanged(species: PetSpecies, name: String, at: Date)
    case sessionStarted(
        goal: String,
        goalMode: FocusGoalMode,
        duration: TimeInterval,
        remindersAvailable: Bool,
        at: Date
    )
    case shieldRequestReceived(at: Date)
    case accessRequestCancelled(at: Date)
    case accessRequestSubmitted(reason: AccessReasonKind, at: Date)
    case returnToFocusRequested(at: Date)
    case sessionEnded(at: Date)
    case completionDismissed(at: Date)
    case reconcile(at: Date)
}

nonisolated enum FriendMVPEffect: Equatable, Sendable {
    case applyProtection
    case clearProtection
    case reapplyProtection
    case scheduleFocusDeadline(monitorID: UUID, deadline: Date)
    case cancelFocusDeadline(monitorID: UUID?)
    case scheduleAccessReminders(windowID: UUID, startedAt: Date)
    case cancelAccessReminders(windowID: UUID?)
    case syncLiveActivity
    case persist
}

nonisolated struct FriendMVPReduction: Equatable, Sendable {
    let snapshot: FriendMVPSnapshot
    let effects: [FriendMVPEffect]
}

nonisolated enum FriendMVPReducer {
    static let accessWindowDuration: TimeInterval = 60 * 60

    static func reduce(
        snapshot: FriendMVPSnapshot,
        event: FriendMVPEvent
    ) -> FriendMVPReduction {
        var next = snapshot
        var effects: [FriendMVPEffect] = []

        switch event {
        case .petAdopted(let species, let name, let now):
            next.pet = species
            next.petName = normalizedName(name, fallback: species.defaultName)
            next.phase = .setup
            next.updatedAt = now
            effects = [.persist]

        case .petChanged(let species, let name, let now):
            guard next.phase == .setup, next.pet != nil, next.pet != species else {
                return .init(snapshot: next, effects: [])
            }
            next.pet = species
            next.petName = normalizedName(name, fallback: species.defaultName)
            next.bondPoints = 0
            next.completedSessions = 0
            next.goal = ""
            next.goalMode = .specific
            next.updatedAt = now
            effects = [.persist]

        case .sessionStarted(let goal, let goalMode, let duration, let remindersAvailable, let now):
            guard next.pet != nil else {
                return .init(snapshot: next, effects: [])
            }
            let normalizedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedGoal.isEmpty,
                  FriendBetaPreferences.supportedFocusDurations.contains(duration) else {
                return .init(snapshot: next, effects: [])
            }
            next.goal = normalizedGoal
            next.goalMode = goalMode
            next.plannedFocusDuration = duration
            next.remainingFocusDuration = duration
            let focusDeadline = now.addingTimeInterval(duration)
            let focusMonitorID = UUID()
            next.focusDeadline = focusDeadline
            next.focusMonitorID = focusMonitorID
            next.phase = .focusing
            next.accessWindowID = nil
            next.accessStartedAt = nil
            next.accessDeadline = nil
            next.accessRequestCount = 0
            next.totalAccessDuration = 0
            next.latestReason = nil
            next.remindersAvailable = remindersAvailable
            next.updatedAt = now
            effects = [
                .applyProtection,
                .scheduleFocusDeadline(
                    monitorID: focusMonitorID,
                    deadline: focusDeadline
                ),
                .syncLiveActivity,
                .persist,
            ]

        case .shieldRequestReceived(let now):
            guard next.phase == .focusing else {
                return .init(snapshot: next, effects: [])
            }
            next.phase = .requestingAccess
            next.updatedAt = now
            effects = [.persist]

        case .accessRequestCancelled(let now):
            guard next.phase == .requestingAccess else {
                return .init(snapshot: next, effects: [])
            }
            next.phase = .focusing
            next.updatedAt = now
            effects = [.persist]

        case .accessRequestSubmitted(let reason, let now):
            guard next.phase == .requestingAccess else {
                return .init(snapshot: next, effects: [])
            }
            let windowID = UUID()
            let focusMonitorID = next.focusMonitorID
            next.remainingFocusDuration = max(
                1,
                next.focusDeadline.map { max(0, $0.timeIntervalSince(now)) }
                    ?? next.remainingFocusDuration
            )
            next.focusDeadline = nil
            next.focusMonitorID = nil
            next.phase = .accessWindow
            next.accessWindowID = windowID
            next.accessStartedAt = now
            next.accessDeadline = now.addingTimeInterval(accessWindowDuration)
            next.accessRequestCount += 1
            next.latestReason = reason
            next.updatedAt = now
            effects = [
                .cancelFocusDeadline(monitorID: focusMonitorID),
                .clearProtection,
                .scheduleAccessReminders(windowID: windowID, startedAt: now),
                .syncLiveActivity,
                .persist,
            ]

        case .returnToFocusRequested(let now):
            guard next.phase == .accessWindow else {
                return .init(snapshot: next, effects: [])
            }
            let windowID = next.accessWindowID
            if let accessStartedAt = next.accessStartedAt {
                next.totalAccessDuration += max(0, now.timeIntervalSince(accessStartedAt))
            }
            next.phase = .focusing
            let focusDeadline = now.addingTimeInterval(max(1, next.remainingFocusDuration))
            let focusMonitorID = UUID()
            next.focusDeadline = focusDeadline
            next.focusMonitorID = focusMonitorID
            clearAccessWindow(in: &next)
            next.updatedAt = now
            effects = [
                .cancelFocusDeadline(monitorID: nil),
                .reapplyProtection,
                .scheduleFocusDeadline(
                    monitorID: focusMonitorID,
                    deadline: focusDeadline
                ),
                .cancelAccessReminders(windowID: windowID),
                .syncLiveActivity,
                .persist,
            ]

        case .sessionEnded(let now):
            guard next.phase == .focusing
                    || next.phase == .requestingAccess
                    || next.phase == .accessWindow else {
                return .init(snapshot: next, effects: [])
            }
            let windowID = next.accessWindowID
            let focusMonitorID = next.focusMonitorID
            if next.phase == .accessWindow, let accessStartedAt = next.accessStartedAt {
                next.totalAccessDuration += max(0, now.timeIntervalSince(accessStartedAt))
            }
            next.phase = .setup
            next.focusDeadline = nil
            next.focusMonitorID = nil
            clearAccessWindow(in: &next)
            next.updatedAt = now
            effects = [
                .cancelFocusDeadline(monitorID: focusMonitorID),
                .clearProtection,
                .cancelAccessReminders(windowID: windowID),
                .syncLiveActivity,
                .persist,
            ]

        case .completionDismissed(let now):
            guard next.phase == .completed else {
                return .init(snapshot: next, effects: [])
            }
            next.phase = .setup
            next.focusDeadline = nil
            next.focusMonitorID = nil
            next.updatedAt = now
            effects = [.persist]

        case .reconcile(let now):
            if next.phase == .focusing,
               let focusDeadline = next.focusDeadline,
               now >= focusDeadline {
                next.phase = .completed
                next.remainingFocusDuration = 0
                next.focusDeadline = nil
                let focusMonitorID = next.focusMonitorID
                next.focusMonitorID = nil
                next.completedSessions += 1
                next.bondPoints += 10
                next.updatedAt = now
                effects = [
                    .cancelFocusDeadline(monitorID: focusMonitorID),
                    .clearProtection,
                    .cancelAccessReminders(windowID: nil),
                    .syncLiveActivity,
                    .persist,
                ]
            } else if next.phase == .accessWindow,
                      let accessDeadline = next.accessDeadline,
                      now >= accessDeadline {
                let windowID = next.accessWindowID
                if let accessStartedAt = next.accessStartedAt {
                    next.totalAccessDuration += max(0, accessDeadline.timeIntervalSince(accessStartedAt))
                }
                next.phase = .setup
                next.focusDeadline = nil
                next.focusMonitorID = nil
                clearAccessWindow(in: &next)
                next.updatedAt = now
                effects = [
                    .clearProtection,
                    .cancelAccessReminders(windowID: windowID),
                    .syncLiveActivity,
                    .persist,
                ]
            }
        }

        return .init(snapshot: next, effects: effects)
    }

    private static func normalizedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(20))
    }

    private static func clearAccessWindow(in snapshot: inout FriendMVPSnapshot) {
        snapshot.accessWindowID = nil
        snapshot.accessStartedAt = nil
        snapshot.accessDeadline = nil
    }
}

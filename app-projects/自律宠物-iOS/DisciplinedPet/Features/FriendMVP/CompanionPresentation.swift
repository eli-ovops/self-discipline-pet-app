import Foundation

/// A presentation-only identity layer. The persisted `.cat` / `.dog` values
/// remain the compatibility identifiers for Milo and Max respectively.
nonisolated enum CompanionPresentation {
    /// A deliberately text-free brand mark shared by the static launch asset
    /// and the short, presentation-only opening moment. It has no domain or
    /// persistence responsibility.
    enum DoublePawBranding {
        enum Mark: Equatable, Sendable {
            case cat
            case dog
        }

        static let marks: [Mark] = [.cat, .dog]
        static let visualText: [String] = []
        static let accessibilityLabel: LocalizedStringResource = "Cat paw and dog paw"
        static let nonReducedMotionDuration: TimeInterval = 0.66
    }

    /// Presentation routing for the Setup → companion confirmation surface.
    /// Confirming the already persisted companion is a navigation success, not
    /// a failed companion-change mutation.
    enum SetupCompanionConfirmationRoute: Equatable, Sendable {
        case returnToTaskSetup
        case commitCompanionChange
    }

    static func setupCompanionConfirmationRoute(
        currentPet: PetSpecies?,
        selectedPet: PetSpecies
    ) -> SetupCompanionConfirmationRoute {
        currentPet == selectedPet ? .returnToTaskSetup : .commitCompanionChange
    }

    /// Presentation-only routing for DURATION_REACTION_TRIAL_ASSETS. These
    /// trial images are deliberately restricted to the Task Setup duration
    /// picker; they do not alter the persisted session, timer, or pet state.
    enum DurationReactionAsset: Equatable, Sendable {
        case approvedDefault
        case trial(String)
    }

    static func durationReactionAsset(
        for species: PetSpecies,
        duration: TimeInterval
    ) -> DurationReactionAsset {
        switch (species, Int(duration.rounded())) {
        case (.cat, 45 * 60): .trial("FocumiMiloDuration45")
        case (.cat, 60 * 60): .trial("FocumiMiloDuration60")
        case (.cat, 120 * 60): .trial("FocumiMiloDuration120")
        case (.dog, 45 * 60): .trial("FocumiMaxDuration45")
        case (.dog, 60 * 60): .trial("FocumiMaxDuration60")
        case (.dog, 120 * 60): .trial("FocumiMaxDuration120")
        default: .approvedDefault
        }
    }

    static func assetName(for species: PetSpecies, mood: PetMood) -> String {
        switch (species, mood) {
        case (.cat, .welcome): "FocumiMiloIdle"
        case (.cat, .focusing): "FocumiMiloFocus"
        case (.cat, .waiting): "FocumiMiloWaiting"
        case (.cat, .celebrating): "FocumiMiloComplete"
        case (.dog, .welcome): "FocumiMaxIdle"
        case (.dog, .focusing): "FocumiMaxFocus"
        case (.dog, .waiting): "FocumiMaxWaiting"
        case (.dog, .celebrating): "FocumiMaxComplete"
        }
    }

    /// Pure presentation routing after existing state has restored; it owns no
    /// reducer event, store write, or new state machine.
    static func v06OpeningRoute(
        phase: FriendMVPPhase,
        dataRecoveryNeeded: Bool,
        capabilityState: P0CapabilityState,
        isPermissionPresentationActive: Bool = false
    ) -> V06OpeningRoute {
        if capabilityState.latestErrorCode != nil { return .error }
        if dataRecoveryNeeded || capabilityState.phase == .recoveryRequired { return .recovery }
        // An authorization value is restored capability data, not a page route.
        // Only a currently presented system permission/selection surface bypasses
        // the normal idle brand moment.
        if isPermissionPresentationActive { return .permission }
        switch phase {
        case .focusing, .requestingAccess, .accessWindow, .completed: return .unfinishedSession
        case .onboarding, .setup: return .brandMoment
        }
    }

    static func displayName(for species: PetSpecies?, storedName: String) -> String {
        switch species {
        case .dog:
            return "Max"
        case .cat:
            let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Milo" : trimmed
        case nil:
            return storedName
        }
    }

    static func displayName(for species: PetSpecies) -> String {
        species == .cat ? "Milo" : "Max"
    }

    static func accessibilityDescription(for species: PetSpecies, mood: PetMood) -> LocalizedStringResource {
        switch (species, mood) {
        case (.cat, .welcome): "Milo, an orange tabby cat, is here to begin with you"
        case (.cat, .focusing): "Milo, an orange tabby cat, is reading beside your page"
        case (.cat, .waiting): "Milo, an orange tabby cat, is holding your bookmark"
        case (.cat, .celebrating): "Milo, an orange tabby cat, has placed a completion stamp"
        case (.dog, .welcome): "Max, a black-and-white husky puppy, is here to begin with you"
        case (.dog, .focusing): "Max, a black-and-white husky puppy, is reading beside your page"
        case (.dog, .waiting): "Max, a black-and-white husky puppy, is holding your bookmark"
        case (.dog, .celebrating): "Max, a black-and-white husky puppy, has placed a completion stamp"
        }
    }
}

nonisolated enum V06OpeningRoute: Equatable, Sendable {
    case brandMoment
    case unfinishedSession
    case recovery
    case permission
    case error
}

@MainActor
extension FriendMVPModel {
    /// Read-only convenience for views. It does not persist or normalize the
    /// stored identity/name and therefore cannot alter an existing session.
    var presentedPetName: String {
        CompanionPresentation.displayName(for: snapshot.pet, storedName: snapshot.petName)
    }
}

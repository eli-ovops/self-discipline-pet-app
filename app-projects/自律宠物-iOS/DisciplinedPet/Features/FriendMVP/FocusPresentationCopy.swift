import Foundation

/// A lightweight UI preference. The persisted raw value is intentionally kept
/// outside the session and companion stores so existing local data remains
/// unchanged.
nonisolated enum FocumiInterfaceLanguage: String, CaseIterable, Sendable {
    case system
    case chinese
    case english

    static let storageKey = "focumi.interface-language"

    private var settingsLabel: String {
        switch self {
        case .system: "Follow System"
        case .chinese: "Chinese"
        case .english: "English"
        }
    }

    func settingsLabel(locale: Locale) -> String {
        FocumiSettingsCopy.text(settingsLabel, locale: locale)
    }

    static func resolvedLocale(
        selection: String,
        systemPreferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        switch Self(rawValue: selection) ?? .system {
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        case .system:
            let preferredLanguage = systemPreferredLanguages.first ?? Locale.current.identifier
            return isChineseLanguage(preferredLanguage)
                ? Locale(identifier: "zh-Hans")
                : Locale(identifier: "en")
        }
    }

    private static func isChineseLanguage(_ identifier: String) -> Bool {
        Locale(identifier: identifier).language.languageCode?.identifier == "zh"
    }
}

/// Settings content allowed in the production interface. The historical P0
/// technical verification screen has no production settings entry.
nonisolated enum FocumiSettingsPresentation {
    enum Item: CaseIterable, Hashable, Sendable {
        case companion
        case language
        case focusMusic
        case permissions
        case relationshipStage
        case completedFocusSessions
        case timeTogether
        case sharedMemories
        case defaultFocusDuration
        case localData
        case technicalDiagnostics
    }

    static let productionItems: Set<Item> = [
        .companion,
        .language,
        .focusMusic,
        .permissions,
    ]

    static let hiddenItems = Set(Item.allCases).subtracting(productionItems)
}

/// The production Settings surface always resolves through the App-level
/// locale injected by `FocumiProductionRoot`. This avoids mixing SwiftUI's
/// ambient/system resolution with values that were eagerly localized using
/// `Locale.current`.
nonisolated enum FocumiSettingsCopy {
    static func text(_ key: String, locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func relationshipStageName(_ stage: CompanionRelationshipStage, locale: Locale) -> String {
        text(stage.localizationKey, locale: locale)
    }

    static func musicTrackName(_ track: FocusMusicTrack, locale: Locale) -> String {
        text(track.localizationKey, locale: locale)
    }
}

private extension CompanionRelationshipStage {
    nonisolated var localizationKey: String {
        switch self {
        case .firstHello: "Just met"
        case .gettingAcquainted: "Getting acquainted"
        case .growingTrust: "Growing trust"
        case .inSync: "In sync"
        case .lastingCompanions: "Lasting companions"
        }
    }
}

private extension FocusMusicTrack {
    nonisolated var localizationKey: String {
        switch self {
        case .firstLight: "First Light"
        case .budding: "Budding"
        case .deepBlue: "Deep Blue"
        }
    }
}

nonisolated enum FocusPresentationCopy {
    static func durationLabel(minutes: Int, locale: Locale) -> String {
        guard locale.language.languageCode?.identifier == "zh" else {
            return "\(minutes) min"
        }
        if minutes >= 120 {
            return String(localized: "2 hours", locale: locale)
        }
        return String(localized: "\(minutes) min", locale: locale)
    }

    static func focusHeader(petName: String, locale: Locale? = nil) -> String {
        let source = "\(petName) is here, working on this with you"
        guard let locale else {
            return String(
                localized: "\(petName) is here, working on this with you",
                comment: "Focus-session heading; placeholder is the companion's chosen name."
            )
        }
        guard locale.language.languageCode?.identifier == "zh" else { return source }
        return String(
            localized: "\(petName) is here, working on this with you",
            locale: locale,
            comment: "Focus-session heading; placeholder is the companion's chosen name."
        )
    }

    static func returnNotice(petName: String, locale: Locale = .current) -> String {
        String(
            localized: "\(petName) is waiting here. When things are handled, you can continue together while Focumi asks iPhone to limit the selected apps again.",
            locale: locale,
            comment: "Return screen status; placeholder is the companion's chosen name."
        )
    }

    static func accessRequestHeader(petName: String, locale: Locale = .current) -> String {
        String(
            localized: "\(petName) is waiting here",
            locale: locale,
            comment: "Temporary-access heading; placeholder is the companion's chosen name."
        )
    }

    static func accessRequestInstruction(petName: String, locale: Locale = .current) -> String {
        String(
            localized: "Take care of what you need. \(petName) will keep this focus ready for your return.",
            locale: locale,
            comment: "Temporary-access supporting text; placeholder is the companion's chosen name."
        )
    }

    static func completionMessage(petName: String, locale: Locale = .current) -> String {
        String(
            localized: "\(petName) stayed with you through this focus session.",
            locale: locale,
            comment: "Completion message; placeholder is the companion's chosen name."
        )
    }

    static func completionMoment(
        petName: String,
        duration: String,
        locale: Locale = .current
    ) -> String {
        String(
            localized: "\(petName) spent \(duration) with you on this page.",
            locale: locale,
            comment: "Completion detail; first placeholder is the companion name, second is focus duration."
        )
    }

    static func selectedDistractingApps(count: Int, locale: Locale = .current) -> String {
        String(
            localized: "\(count) distracting apps selected",
            locale: locale,
            comment: "Compact setup readiness; placeholder is the number of user-selected distracting apps."
        )
    }
}

/// Presentation-only readiness model. It never asserts that iOS has confirmed a Shield.
nonisolated enum FocusPactReadinessPresentation: Equatable {
    case needsScreenTime
    case needsApps
    case ready(selectedApps: Int)

    static func make(isScreenTimeApproved: Bool, selectedAppCount: Int) -> Self {
        guard isScreenTimeApproved else { return .needsScreenTime }
        guard selectedAppCount > 0 else { return .needsApps }
        return .ready(selectedApps: selectedAppCount)
    }

    var iconKind: FocumiCompanionIconKind {
        switch self {
        case .needsScreenTime: .pageTurn
        case .needsApps: .bookmarkPaw
        case .ready: .pawStamp
        }
    }
}

nonisolated enum FocumiCompanionIconKind: Equatable {
    case bookmarkPaw
    case pageTurn
    case companionClock
    case pencilBloom
    case scarfBow
    case pawStamp
    case settingsPage
}

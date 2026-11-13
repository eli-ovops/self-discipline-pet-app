import Foundation

nonisolated enum AppGroupKeys {
    static let suiteName = "group.com.cczij.disciplinedpet"
    static let activitySelection = "p0.activity-selection"
    static let sessionSnapshot = "p0.session-snapshot"
    static let pendingShieldIntent = "p0.pending-shield-intent"
    static let monitorEvent = "p0.monitor-event"
    static let focusDeadlineMonitor = "friend-beta.focus-deadline-monitor.v1"
    static let commandReceipt = "p0.command-receipt"
    // Presentation only: lets the system-owned Shield surface use the companion
    // the person chose. It never reports or infers protection state.
    static let shieldCompanionSpecies = "friend-beta.shield-companion-species.v1"
}

nonisolated enum ShieldCompanionPresentation {
    static func iconAssetName(for persistedSpecies: String?) -> String {
        switch persistedSpecies {
        case "dog": "FocumiMaxShieldPortrait"
        case "cat", .none: "FocumiMiloShieldPortrait"
        default: "FocumiMiloShieldPortrait"
        }
    }
}

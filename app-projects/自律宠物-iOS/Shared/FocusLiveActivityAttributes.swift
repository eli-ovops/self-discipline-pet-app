import ActivityKit
import Foundation
import SwiftUI

nonisolated struct FocusLiveActivityAttributes: ActivityAttributes, Hashable, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let pet: FocusLiveActivityPet
        let petName: String
        let goal: String
        let phase: FocusLiveActivityPhase
        let deadline: Date
    }

    let sessionID: UUID
}

nonisolated enum FocusLiveActivityPet: String, Codable, Hashable, Sendable {
    case cat
    case dog
}

nonisolated enum FocusLiveActivityPhase: String, Codable, Hashable, Sendable {
    case focusing
    case waitingToReturn
    case returning
}

extension FocusLiveActivityPhase {
    var statusText: LocalizedStringResource {
        switch self {
        case .focusing: "Focus together"
        case .waitingToReturn: "Your page is held"
        case .returning: "Requesting focus again"
        }
    }

    var compactStatusText: LocalizedStringResource {
        switch self {
        case .focusing: "Focus"
        case .waitingToReturn: "Held"
        case .returning: "Requesting"
        }
    }
}

extension FocusLiveActivityPet {
    nonisolated func presentationName(storedName: String) -> String {
        switch self {
        case .cat:
            storedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Milo" : storedName
        case .dog:
            "Max"
        }
    }

    /// These are deliberately small, opaque, precomposed images. WidgetKit can render
    /// them independently of the large transparent animation frames used by the app.
    func liveActivityBadgeAssetName(for phase: FocusLiveActivityPhase) -> String {
        switch (self, phase) {
        case (.cat, .focusing): "FocumiMiloLAFocus"
        case (.cat, .waitingToReturn): "FocumiMiloLAWaiting"
        case (.cat, .returning): "FocumiMiloLAReturning"
        case (.dog, .focusing): "FocumiMaxLAFocus"
        case (.dog, .waitingToReturn): "FocumiMaxLAWaiting"
        case (.dog, .returning): "FocumiMaxLAReturning"
        }
    }

    var liveActivityFallbackAssetName: String {
        switch self {
        case .cat: "FocumiMiloLAFocus"
        case .dog: "FocumiMaxLAFocus"
        }
    }
}

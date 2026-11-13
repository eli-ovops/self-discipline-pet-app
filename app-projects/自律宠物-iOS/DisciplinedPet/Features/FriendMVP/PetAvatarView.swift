import Foundation
import SwiftUI
import UIKit

nonisolated enum PetActivityScene: Equatable, Sendable {
    case companion
    case homework
    case computer
    case waiting
    case playBall
    case returning
    case starting

    static func forPhase(_ phase: FriendMVPPhase) -> Self {
        switch phase {
        case .setup:
            .homework
        case .focusing:
            .computer
        case .completed:
            .playBall
        case .accessWindow:
            .waiting
        case .onboarding, .requestingAccess:
            .companion
        }
    }

    var presentsReturnCue: Bool {
        self == .waiting || self == .returning
    }
}

nonisolated enum PetAnimationClip: CaseIterable, Equatable, Sendable {
    case idle
    case tap
    case focus
    case celebrate
}

nonisolated enum PetFrameAnimation {
    static let minimumFrameCount = 3
    static let tapCooldown: TimeInterval = 1.5

    static func frameNames(
        for species: PetSpecies,
        clip: PetAnimationClip
    ) -> [String] {
        // Legacy frame names remain only for testable compatibility; Checkpoint A
        // no longer presents them in the UI.
        let prefix = species == .cat ? "Milo" : "Max"
        let action: String
        switch clip {
        case .idle: action = "Idle"
        case .tap: action = "Tap"
        case .focus: action = "Focus"
        case .celebrate: action = "Celebrate"
        }
        let frameNumbers = clip == .celebrate ? [1, 2, 4] : [1, 2, 3, 4]
        return frameNumbers.map { "\(prefix)\(action)\(String(format: "%02d", $0))" }
    }

    static func frameDurations(for clip: PetAnimationClip) -> [TimeInterval] {
        switch clip {
        case .idle: [2.8, 0.12, 0.18, 0.9]
        case .tap: [0.16, 0.16, 0.16, 0.28]
        case .focus: [0.72, 0.72, 0.52, 0.72]
        // One complete, non-looping celebration lands inside the 2–4 second
        // signature-moment window. It never stands in for protection status.
        case .celebrate: [0.58, 0.70, 1.15]
        }
    }

    static func duration(of clip: PetAnimationClip) -> TimeInterval {
        frameDurations(for: clip).reduce(0, +)
    }

    static func frameIndex(
        for clip: PetAnimationClip,
        at time: TimeInterval,
        repeats: Bool = true
    ) -> Int {
        let durations = frameDurations(for: clip)
        let duration = durations.reduce(0, +)
        guard duration > 0 else { return 0 }

        var cursor: TimeInterval
        if repeats {
            cursor = time.truncatingRemainder(dividingBy: duration)
            if cursor < 0 { cursor += duration }
        } else {
            cursor = min(max(0, time), duration.nextDown)
        }

        for (index, frameDuration) in durations.enumerated() {
            if cursor < frameDuration {
                return index
            }
            cursor -= frameDuration
        }
        return durations.indices.last ?? 0
    }

    static func frameName(
        for species: PetSpecies,
        clip: PetAnimationClip,
        at time: TimeInterval,
        repeats: Bool = true
    ) -> String {
        let frames = frameNames(for: species, clip: clip)
        return frames[frameIndex(for: clip, at: time, repeats: repeats)]
    }

    static func baseClip(for activity: PetActivityScene) -> PetAnimationClip {
        switch activity {
        case .companion, .waiting, .returning, .starting: .idle
        case .homework, .computer: .focus
        case .playBall: .celebrate
        }
    }
}

/// Playback metadata for the approved, per-companion Return production frames.
/// This is presentation-only: it never changes a session, a deadline, Shield,
/// ManagedSettings, or Live Activity truth. Each return sequence is non-looping
/// and lands on its matching approved Focus pose when Reduce Motion is enabled.
nonisolated enum ReturnSignatureAnimation {
    static let framesPerSecond = 12
    static let holdFrames = [3, 2, 4, 3, 3, 2, 2, 2, 3, 3, 3, 4]
    static let frameCount = holdFrames.count

    static var duration: TimeInterval {
        TimeInterval(holdFrames.reduce(0, +)) / TimeInterval(framesPerSecond)
    }

    static func frameNumber(at elapsed: TimeInterval) -> Int {
        let elapsedFrames = max(0, Int((elapsed * TimeInterval(framesPerSecond)).rounded(.down)))
        var remaining = elapsedFrames

        for (index, hold) in holdFrames.enumerated() {
            if remaining < hold { return index + 1 }
            remaining -= hold
        }
        return frameCount
    }

    static func assetName(for species: PetSpecies, frameNumber: Int) -> String {
        let companion = species == .cat ? "FocumiMilo" : "FocumiMax"
        return "\(companion)ReturnSignature\(String(format: "%03d", min(max(1, frameNumber), frameCount)))"
    }

    static func reduceMotionLandingAssetName(for species: PetSpecies) -> String {
        species == .cat ? "FocumiMiloFocus" : "FocumiMaxFocus"
    }
}

/// The approved Return animation is deliberately local to the Return surface.
/// It cannot block the Return CTA, does not loop, and has no system-success cue.
struct ReturnSignaturePetView: View {
    let species: PetSpecies
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        Group {
            if reduceMotion {
                sprite(named: ReturnSignatureAnimation.reduceMotionLandingAssetName(for: species))
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / Double(ReturnSignatureAnimation.framesPerSecond))) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    sprite(named: ReturnSignatureAnimation.assetName(
                        for: species,
                        frameNumber: ReturnSignatureAnimation.frameNumber(at: elapsed)
                    ))
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { startedAt = Date() }
        .accessibilityHidden(true)
    }

    private func sprite(named name: String) -> some View {
        Image(decorative: name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct PetAvatarView: View {
    let species: PetSpecies
    let mood: PetMood
    let size: CGFloat
    var activity: PetActivityScene = .companion
    var accessibilityName: String?
    var repeatsAnimation = true

    init(
        species: PetSpecies,
        mood: PetMood,
        size: CGFloat,
        activity: PetActivityScene = .companion,
        accessibilityName: String? = nil,
        repeatsAnimation: Bool = true
    ) {
        self.species = species
        self.mood = mood
        self.size = size
        self.activity = activity
        self.accessibilityName = accessibilityName
        self.repeatsAnimation = repeatsAnimation
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reactionCount = 0
    @State private var reactionStartedAt: Date?
    @State private var nextReactionAt = Date.distantPast

    var body: some View {
        ZStack {
            VintagePetSprite(
                species: species,
                mood: mood,
                activity: activity,
                reactionStartedAt: reactionStartedAt,
                reduceMotion: reduceMotion,
                repeatsAnimation: repeatsAnimation,
                size: size
            )

        }
        .frame(width: size, height: size)
        .contentShape(.rect)
        .onTapGesture(perform: playFriendlyReaction)
        .sensoryFeedback(.selection, trigger: reactionCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap for one gentle response")
        .accessibilityAction(named: Text("Say hello")) {
            playFriendlyReaction()
        }
    }

    private var accessibilityLabel: Text {
        if let accessibilityName {
            Text("\(accessibilityName): \(String(localized: mood.accessibilityDescription))")
        } else {
            Text(accessibilityDescription)
        }
    }

    private func playFriendlyReaction() {
        let now = Date()
        guard now >= nextReactionAt else { return }
        reactionCount += 1
        reactionStartedAt = now
        nextReactionAt = now.addingTimeInterval(
            PetFrameAnimation.duration(of: .tap) + PetFrameAnimation.tapCooldown
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(760))
            guard reactionStartedAt == now else { return }
            reactionStartedAt = nil
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "Your companion says hello")
        )
    }

    private var accessibilityDescription: LocalizedStringResource {
        CompanionPresentation.accessibilityDescription(for: species, mood: mood)
    }
}

/// The formal user path uses one approved static pose at a time. It deliberately
/// does not expose tap reactions, timeline-driven transforms, or animation assets.
struct MiloStaticPoseView: View {
    let species: PetSpecies
    let mood: PetMood
    let size: CGFloat
    var accessibilityLabel: String? = nil

    var body: some View {
        Image(decorative: CompanionPresentation.assetName(for: species, mood: mood))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? "")
    }
}

/// A display-only blink for the pre-focus Milo pose. It owns no session data,
/// uses only the two approved transparent images, and stops with the view.
struct MiloBlinkView: View {
    let size: CGFloat
    var accessibilityLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isClosed = false

    var body: some View {
        Image(decorative: isClosed ? "FocumiMiloIdleClosed" : "FocumiMiloIdle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .transaction { $0.animation = nil }
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? "")
            .task(id: reduceMotion) {
                guard !reduceMotion else {
                    isClosed = false
                    return
                }

                do {
                    try await Task.sleep(for: .milliseconds(Int.random(in: 1_500...2_500)))
                    while !Task.isCancelled {
                        isClosed = true
                        try await Task.sleep(for: .milliseconds(83))
                        isClosed = false
                        try await Task.sleep(for: .milliseconds(Int.random(in: 4_000...7_000)))
                    }
                } catch {
                    isClosed = false
                }
            }
            .onDisappear { isClosed = false }
    }
}

nonisolated enum VintagePetAsset {
    static func name(species: PetSpecies, mood: PetMood, activity: PetActivityScene, isResponding: Bool) -> String {
        // `.dog` remains the persisted technical identity. It intentionally routes
        // to Max's approved static family; old frame sequences remain compatibility
        // code only and are never used by this renderer.
        let companion = species == .cat ? "FocumiMilo" : "FocumiMax"
        if isResponding { return companion + "Tap" }
        if mood == .celebrating { return companion + "Complete" }
        switch activity {
        case .companion: return companion + "Idle"
        case .homework: return companion + "Pact"
        case .computer: return companion + "Focus"
        case .waiting: return companion + "Waiting"
        case .playBall: return companion + "Complete"
        case .returning: return companion + "Return"
        case .starting: return companion + "Start"
        }
    }
}

private struct VintagePetSprite: View {
    let species: PetSpecies
    let mood: PetMood
    let activity: PetActivityScene
    let reactionStartedAt: Date?
    let reduceMotion: Bool
    let repeatsAnimation: Bool
    let size: CGFloat

    @State private var performanceStartedAt = Date()
    @State private var completionReactionFinished = false

    private var manifest: CompanionPerformanceManifest {
        CompanionPerformanceManifest.forSpecies(species)
    }

    private var beat: CompanionPerformanceBeat {
        manifest.beat(for: mood, activity: activity)
    }

    var body: some View {
        Group {
            if reduceMotion || (beat == .completionReaction && completionReactionFinished) {
                sprite(named: assetName(isResponding: false), pose: .identity)
            } else {
                // The clock chooses a deterministic pose from elapsed time rather
                // than incrementing mutable frame state. A delayed redraw can land
                // on the correct pose but cannot recenter, scale-drift, or replay a
                // stale frame. Apple may reduce TimelineView cadence when needed;
                // every lower-cadence pose remains an honest fixed-anchor landing.
                TimelineView(.periodic(from: performanceStartedAt, by: 1.0 / 12.0)) { context in
                    let isResponding = isResponding(at: context.date)
                    let pose = isResponding
                        ? CompanionPerformancePose.identity
                        : manifest.pose(
                            for: beat,
                            elapsed: context.date.timeIntervalSince(performanceStartedAt),
                            repeats: beat == .completionReaction ? false : repeatsAnimation
                        )
                    sprite(named: assetName(isResponding: isResponding), pose: pose)
                }
            }
        }
        .onAppear {
            performanceStartedAt = Date()
            completionReactionFinished = false
        }
        .task(id: beat) {
            guard beat == .completionReaction, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(manifest.completionDuration))
            guard !Task.isCancelled else { return }
            completionReactionFinished = true
        }
    }

    private func isResponding(at date: Date) -> Bool {
        if let reactionStartedAt {
            let elapsed = date.timeIntervalSince(reactionStartedAt)
            return elapsed >= 0 && elapsed < PetFrameAnimation.duration(of: .tap)
        }
        return false
    }

    private func assetName(isResponding: Bool) -> String {
        VintagePetAsset.name(species: species, mood: mood, activity: activity, isResponding: isResponding)
    }

    private func sprite(named name: String, pose: CompanionPerformancePose) -> some View {
        let renderedSide = size * 0.88
        return Image(decorative: name)
            .resizable()
            .scaledToFit()
            // The source itself is the fixed 1254px composition. We preserve
            // the historical visual size but animate from the declared book or
            // ground root, never from the transparent alpha bounding box.
            .frame(width: renderedSide, height: renderedSide)
            .scaleEffect(
                x: pose.horizontalScale,
                y: pose.verticalScale,
                anchor: .bottom
            )
            .offset(y: manifest.compensatedYOffset(
                for: pose.verticalScale,
                renderedSide: renderedSide
            ))
            .frame(width: renderedSide, height: size * 0.98)
    }
}

private extension PetSpecies {
    var accentColor: Color {
        switch self {
        case .cat: .cocoonApricot
        case .dog: .cocoonAccentSoft
        }
    }
}

private extension PetMood {
    var symbolName: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .focusing: "book.closed.fill"
        case .waiting: "arrow.uturn.backward.circle.fill"
        case .celebrating: "sparkles"
        }
    }

    var accessibilityDescription: LocalizedStringResource {
        switch self {
        case .welcome: "ready to begin together"
        case .focusing: "focusing with you"
        case .waiting: "holding your place until you return"
        case .celebrating: "celebrating this completed focus"
        }
    }

}

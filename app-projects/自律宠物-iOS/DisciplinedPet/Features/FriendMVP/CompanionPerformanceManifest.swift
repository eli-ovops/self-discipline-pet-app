import CoreGraphics
import Foundation

/// Per-companion presentation metadata for the Phase 1 life-performance layer.
///
/// This is deliberately not session data. The 1254px source canvas, the root
/// anchor, and the page/ground reference are fixed so a breathing transform
/// never recenters an alpha bounding box or reflows the book from frame to
/// frame. Milo and Max have independent assets and timing; the `.dog` storage
/// identifier still only maps to Max at the presentation boundary.
nonisolated enum CompanionPerformanceBeat: String, CaseIterable, Equatable, Sendable {
    case idleBreathing
    case pageAttention
    case focusedBreathing
    case waitingBreathing
    case completionReaction
}

nonisolated struct CompanionPerformanceManifest: Equatable, Sendable {
    let character: String
    let canvasSide: Int
    let rootAnchor: String
    let bookOrGroundReference: String
    let rootAnchorY: CGFloat

    /// Values are intentionally small because each source image already
    /// contains its page and book contact. A larger transform would make the
    /// flattened page artwork slide or imply a new, unapproved action.
    let idlePeriod: TimeInterval
    let idleVerticalAmplitude: CGFloat
    let focusedPeriod: TimeInterval
    let focusedVerticalAmplitude: CGFloat
    let waitingPeriod: TimeInterval
    let waitingVerticalAmplitude: CGFloat
    let completionDuration: TimeInterval
    let completionVerticalAmplitude: CGFloat
    let completionHorizontalAmplitude: CGFloat

    static func forSpecies(_ species: PetSpecies) -> Self {
        switch species {
        case .cat:
            // Milo's book spine is the root. His life comes from a restrained
            // low-body breath; eyes-first recognition and paw contact remain
            // the separately authored Return frames.
            Self(
                character: "Milo",
                canvasSide: 1254,
                rootAnchor: "open-book spine, lower centre",
                bookOrGroundReference: "sage bookmark midpoint and book spine",
                rootAnchorY: 0.842,
                idlePeriod: 3.8,
                idleVerticalAmplitude: 0.005,
                focusedPeriod: 5.2,
                focusedVerticalAmplitude: 0.003,
                waitingPeriod: 5.7,
                waitingVerticalAmplitude: 0.0025,
                completionDuration: 1.35,
                completionVerticalAmplitude: 0.012,
                completionHorizontalAmplitude: 0.002
            )
        case .dog:
            // Max's broader forepaw/chest and blue bookmark are the root. His
            // rhythm is slower and a touch broader than Milo's, never a cat
            // animation recoloured into a dog asset.
            Self(
                character: "Max",
                canvasSide: 1254,
                rootAnchor: "open-book spine, lower centre",
                bookOrGroundReference: "dusty-blue bookmark midpoint and broad forepaw baseline",
                rootAnchorY: 0.866,
                idlePeriod: 4.35,
                idleVerticalAmplitude: 0.007,
                focusedPeriod: 5.8,
                focusedVerticalAmplitude: 0.004,
                waitingPeriod: 6.1,
                waitingVerticalAmplitude: 0.0035,
                completionDuration: 1.75,
                completionVerticalAmplitude: 0.015,
                completionHorizontalAmplitude: 0.0035
            )
        }
    }

    func beat(for mood: PetMood, activity: PetActivityScene) -> CompanionPerformanceBeat {
        if mood == .celebrating || activity == .playBall { return .completionReaction }
        switch activity {
        case .companion, .starting:
            return .idleBreathing
        case .homework, .returning:
            return .pageAttention
        case .computer:
            return .focusedBreathing
        case .waiting:
            return .waitingBreathing
        case .playBall:
            return .completionReaction
        }
    }

    func pose(
        for beat: CompanionPerformanceBeat,
        elapsed: TimeInterval,
        repeats: Bool
    ) -> CompanionPerformancePose {
        switch beat {
        case .idleBreathing:
            breath(
                elapsed: elapsed,
                period: idlePeriod,
                verticalAmplitude: idleVerticalAmplitude,
                horizontalAmplitude: idleVerticalAmplitude * 0.32,
                repeats: repeats
            )
        case .pageAttention:
            breath(
                elapsed: elapsed,
                period: focusedPeriod,
                verticalAmplitude: focusedVerticalAmplitude * 0.72,
                horizontalAmplitude: focusedVerticalAmplitude * 0.18,
                repeats: repeats
            )
        case .focusedBreathing:
            breath(
                elapsed: elapsed,
                period: focusedPeriod,
                verticalAmplitude: focusedVerticalAmplitude,
                horizontalAmplitude: focusedVerticalAmplitude * 0.2,
                repeats: repeats
            )
        case .waitingBreathing:
            breath(
                elapsed: elapsed,
                period: waitingPeriod,
                verticalAmplitude: waitingVerticalAmplitude,
                horizontalAmplitude: waitingVerticalAmplitude * 0.12,
                repeats: repeats
            )
        case .completionReaction:
            completionPose(at: elapsed)
        }
    }

    /// Keeps the declared root anchor fixed in the app's world space. The
    /// sprite's alpha bbox is never measured or used for centering.
    func compensatedYOffset(for verticalScale: CGFloat, renderedSide: CGFloat) -> CGFloat {
        (1 - rootAnchorY) * (verticalScale - 1) * renderedSide
    }

    private func breath(
        elapsed: TimeInterval,
        period: TimeInterval,
        verticalAmplitude: CGFloat,
        horizontalAmplitude: CGFloat,
        repeats: Bool
    ) -> CompanionPerformancePose {
        guard period > 0 else { return .identity }
        let safeElapsed = max(0, elapsed)
        let localTime = repeats ? safeElapsed.truncatingRemainder(dividingBy: period) : min(safeElapsed, period)
        let phase = (localTime / period) * .pi * 2
        let breath = CGFloat(sin(phase))
        return CompanionPerformancePose(
            horizontalScale: 1 - breath * horizontalAmplitude,
            verticalScale: 1 + breath * verticalAmplitude
        )
    }

    private func completionPose(at elapsed: TimeInterval) -> CompanionPerformancePose {
        guard completionDuration > 0 else { return .identity }
        let progress = min(max(elapsed / completionDuration, 0), 1)
        // A single low perk that returns to the approved Completion pose. The
        // envelope begins and ends at identity, so it cannot loop or jump.
        let envelope = CGFloat(pow(sin(progress * .pi), 2))
        return CompanionPerformancePose(
            horizontalScale: 1 - envelope * completionHorizontalAmplitude,
            verticalScale: 1 + envelope * completionVerticalAmplitude
        )
    }
}

nonisolated struct CompanionPerformancePose: Equatable, Sendable {
    let horizontalScale: CGFloat
    let verticalScale: CGFloat

    static let identity = Self(horizontalScale: 1, verticalScale: 1)
}

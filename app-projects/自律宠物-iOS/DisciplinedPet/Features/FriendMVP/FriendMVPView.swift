import FamilyControls
import Foundation
import SwiftUI
import UIKit

@MainActor
struct FriendMVPView: View {
    let model: FriendMVPModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDiagnostics = false
    @State private var showsSettings = false
    @State private var showsBetaFeedback = false
    @State private var performanceCoordinator = CompanionPerformanceCoordinator()
    @State private var performanceCue: CompanionPerformanceCue?
    @State private var hasPresentedOpeningMoment = false
    @State private var showsOpeningMoment = false
    // This is intentionally view-local presentation state. A confirmed choice
    // still commits through the existing companion-change persistence path.
    @State private var showsMeetMiloFromSetup = false

    private var usesStableDemoPresentation: Bool {
#if DEBUG && targetEnvironment(simulator)
        model.isIntegratedExperienceDemo || model.isOpeningMomentPreview
#else
        false
#endif
    }

    private var usesReturnSignaturePreview: Bool {
#if DEBUG && targetEnvironment(simulator)
        model.isReturnSignaturePreview
#else
        false
#endif
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var capability = model.capability

        NavigationStack {
            ZStack {
                CompanionCocoonBackground(pet: model.snapshot.pet ?? .cat)

                if model.dataRecoveryNeeded {
                    LocalDataRecoveryView(model: model)
                } else if showsMeetMiloFromSetup, model.snapshot.phase == .setup {
                    PetOnboardingView(
                        petName: $model.petNameDraft,
                        adopt: { species in
#if DEBUG
                            let traceID = CompanionConfirmationDebugTrace.begin(
                                selectedPet: species,
                                snapshotPet: model.snapshot.pet,
                                remainingPetChanges: model.preferences.remainingPetChanges,
                                phase: model.snapshot.phase,
                                isPresented: showsMeetMiloFromSetup,
                                dataRecoveryNeeded: model.dataRecoveryNeeded,
                                openingOverlayVisible: showsOpeningMoment,
                                secondaryPresentationVisible: showsDiagnostics || showsSettings || showsBetaFeedback
                            )
#else
                            let traceID: UInt64? = nil
#endif
                            switch CompanionPresentation.setupCompanionConfirmationRoute(
                                currentPet: model.snapshot.pet,
                                selectedPet: species
                            ) {
                            case .returnToTaskSetup:
#if DEBUG
                                CompanionConfirmationDebugTrace.emit(traceID, step: "route", details: "returnToTaskSetup")
#endif
                                showsMeetMiloFromSetup = false
#if DEBUG
                                CompanionConfirmationDebugTrace.emit(
                                    traceID,
                                    step: "presentation-close",
                                    details: "presented=\(showsMeetMiloFromSetup) phase=\(CompanionConfirmationDebugTrace.phaseCode(model.snapshot.phase))"
                                )
#endif
                            case .commitCompanionChange:
#if DEBUG
                                CompanionConfirmationDebugTrace.emit(traceID, step: "route", details: "commitCompanionChange")
#endif
                                let committed = model.confirmSetupCompanionSelection(
                                    species,
                                    companionConfirmationTraceID: traceID
                                )
#if DEBUG
                                CompanionConfirmationDebugTrace.emit(traceID, step: "commit-result", details: "result=\(committed)")
#endif
                                if committed {
                                    showsMeetMiloFromSetup = false
#if DEBUG
                                    CompanionConfirmationDebugTrace.emit(
                                        traceID,
                                        step: "presentation-close",
                                        details: "presented=\(showsMeetMiloFromSetup) snapshot=\(CompanionConfirmationDebugTrace.speciesCode(model.snapshot.pet)) phase=\(CompanionConfirmationDebugTrace.phaseCode(model.snapshot.phase))"
                                    )
#endif
                                } else {
#if DEBUG
                                    CompanionConfirmationDebugTrace.emit(
                                        traceID,
                                        step: "presentation-retained",
                                        details: "presented=\(showsMeetMiloFromSetup) snapshot=\(CompanionConfirmationDebugTrace.speciesCode(model.snapshot.pet))"
                                    )
#endif
                                }
                            }
                        },
                        settingsAction: { showsSettings = true },
                        initialSpecies: model.snapshot.pet ?? .cat
                    )
                } else {
                    switch model.snapshot.phase {
                    case .onboarding:
                        PetOnboardingView(
                            petName: $model.petNameDraft,
                            adopt: model.adopt,
                            settingsAction: { showsSettings = true },
                            initialSpecies: model.snapshot.pet ?? .cat
                        )

                    case .setup:
                        FocumiFocusPactView(
                            model: model,
                            returnToMeetMilo: { showsMeetMiloFromSetup = true },
                            settingsAction: { showsSettings = true }
                        )

                    case .focusing:
                        FocumiFocusPageView(model: model)

                    case .requestingAccess:
                        FocumiAccessRequestPageView(model: model)

                    case .accessWindow:
                        if usesReturnSignaturePreview {
                            // Existing DEBUG-only fixture: presentation only, never a
                            // substitute for Shield or re-lock evidence.
                            FocumiReturnRecognitionView(model: model)
                        } else {
                            FocumiWaitingPageView(model: model)
                        }

                    case .completed:
                        FocumiCompletionPageView(model: model)
                    }
                }

                if showsOpeningMoment {
                    FocumiOpeningMoment(
                        reduceMotion: reduceMotion,
                        finish: { showsOpeningMoment = false }
                    )
                    .allowsHitTesting(false)
                    .zIndex(2)
                }

#if DEBUG && targetEnvironment(simulator)
                if let simulatorFixtureStatus = model.simulatorFixtureStatus {
                    Text(simulatorFixtureStatus)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.cocoonTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .accessibilityLabel(simulatorFixtureStatus)
                        .zIndex(3)
                }
#endif
            }
            .foregroundStyle(Color.cocoonTextPrimary)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // v0.6's formal core flow is intentionally Light Mode only. This is
        // scoped to FriendMVP rather than changing the app-wide theme policy.
        .preferredColorScheme(.light)
        .tint(.cocoonAccent)
        .familyActivityPicker(
            isPresented: $capability.isPickerPresented,
            selection: $capability.selection
        )
        .onChange(of: capability.selection) {
            capability.selectionChanged()
        }
        .onChange(of: capability.latestIntentRecordID) {
            model.routeLatestShieldIntent()
        }
        .onChange(of: scenePhase) {
            model.setAppActive(scenePhase == .active)
            if scenePhase == .active {
                model.reconcile()
            }
        }
        .onChange(of: model.snapshot.phase) { previous, current in
            if current != .setup {
                showsMeetMiloFromSetup = false
            }
            presentPerformanceCue(from: previous, to: current)
            presentBetaFeedbackIfNeeded()
        }
        .task { @MainActor in
            model.setAppActive(scenePhase == .active)
            model.reconcile()
            presentBetaFeedbackIfNeeded()
#if DEBUG && targetEnvironment(simulator)
            if model.isOpeningMomentPreview {
                model.presentIntegratedExperienceDemo(phase: .setup)
                // This fixture deliberately uses the same in-app overlay as a
                // cold setup entry. Its static demo projection must not suppress
                // the overlay it is meant to exercise.
                presentOpeningMomentIfAppropriate(allowStableDemoPresentation: true)
                return
            }
            if model.isReturnSignaturePreview {
                model.presentIntegratedExperienceDemo(phase: .accessWindow)
                return
            }
            if let phase = model.integratedExperienceDemoStaticPhase {
                model.presentIntegratedExperienceDemo(phase: phase)
                return
            }
            await runIntegratedExperienceDemoIfRequested()
#endif
            presentOpeningMomentIfAppropriate()
        }
        .sheet(isPresented: $showsDiagnostics) {
            P0CapabilityView(model: model.capability)
        }
        .sheet(isPresented: $showsSettings) {
            FriendSettingsView(model: model)
        }
        .sheet(isPresented: $showsBetaFeedback) {
            BetaCommercialFeedbackView(
                submit: { understanding, desire, driver, intent, price, customPriceBucket in
                    model.submitBetaFeedback(
                        productUnderstanding: understanding,
                        ownershipDesire: desire,
                        purchaseDriver: driver,
                        purchaseIntent: intent,
                        selectedPrice: price,
                        customPriceBucket: customPriceBucket
                    )
                    showsBetaFeedback = false
                },
                skip: {
                    model.dismissBetaFeedback()
                    showsBetaFeedback = false
                }
            )
            .interactiveDismissDisabled()
        }
    }

    private func presentBetaFeedbackIfNeeded() {
#if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains(
            "--friend-mvp-preview-suppress-beta-feedback"
        ) else { return }
#endif
        guard model.snapshot.phase == .completed,
              model.shouldOfferBetaFeedback,
              !showsBetaFeedback else { return }
        model.openBetaFeedback()
        showsBetaFeedback = true
    }

    private func presentPerformanceCue(
        from previous: FriendMVPPhase,
        to current: FriendMVPPhase
    ) {
        // v0.6 keeps the reducer transition but removes the prior Return
        // animation overlay from the formal path. No extra presentation state is
        // allowed to imply a system re-lock result.
    }

    /// A presentation-only cold-entry moment. It never owns navigation,
    /// persistence, a session, or an iOS protection assertion.
    private func presentOpeningMomentIfAppropriate(
        allowStableDemoPresentation: Bool = false
    ) {
        guard !hasPresentedOpeningMoment,
              (!usesStableDemoPresentation || allowStableDemoPresentation)
        else { return }

        let openingRoute = CompanionPresentation.v06OpeningRoute(
            phase: model.snapshot.phase,
            dataRecoveryNeeded: model.dataRecoveryNeeded,
            capabilityState: model.capability.state,
            isPermissionPresentationActive: model.capability.isPickerPresented
        )
        guard openingRoute == .brandMoment || allowStableDemoPresentation else { return }

        hasPresentedOpeningMoment = true
        // The opening is first rendered in the same main-actor transaction as
        // the recovered root. Its scene-owned timing is started only after that
        // stable first render; this avoids a cross-executor state handoff while
        // UIKit is still attaching the first scene.
        showsOpeningMoment = true
    }

#if DEBUG && targetEnvironment(simulator)
    /// A continuous visual recording fixture. It presents the actual root
    /// screens in one app session while leaving all system-backed facts alone.
    private func runIntegratedExperienceDemoIfRequested() async {
        guard model.isIntegratedExperienceDemo else { return }

        if let raw = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--friend-mvp-integrated-demo-delay-ms=") })?
            .split(separator: "=", maxSplits: 1)
            .last,
           let milliseconds = Int(raw) {
            try? await Task.sleep(for: .milliseconds(min(max(milliseconds, 0), 3_000)))
        }

        let fastCapture = ProcessInfo.processInfo.arguments.contains(
            "--friend-mvp-integrated-demo-fast-capture"
        )
        let sequence: [(FriendMVPPhase, Duration)] = fastCapture
            ? [
                // Isolated capture mode: each real root gets a readable hold, while
                // the full sequence remains below the simulator recorder's observed
                // variable-frame-duration limit. It never invokes product effects.
                (.onboarding, .seconds(3)),
                (.setup, .seconds(3)),
                (.focusing, .seconds(3)),
                (.requestingAccess, .seconds(3)),
                (.accessWindow, .seconds(4)),
                (.focusing, .seconds(3)),
                (.completed, .seconds(4)),
            ]
            : [
                (.onboarding, .seconds(12)),
                (.setup, .seconds(8)),
                (.focusing, .seconds(8)),
                (.requestingAccess, .seconds(8)),
                (.accessWindow, .seconds(10)),
                (.focusing, .seconds(8)),
                (.completed, .seconds(10)),
            ]

        for (phase, hold) in sequence {
            guard !Task.isCancelled else { return }
            model.presentIntegratedExperienceDemo(phase: phase)
            await Task.yield()
            try? await Task.sleep(for: hold)
        }
    }
#endif
}

private struct FocumiReturnRecognitionOverlay: View {
    let species: PetSpecies
    let goal: String

    var body: some View {
        FocumiReturnRecognitionSurface(
            goal: goal,
            showAction: true
        )
    }
}

private struct CinematicFocusBeam: View {
    enum Treatment {
        case start
        case returning
        case completion
    }

    let treatment: Treatment

    var body: some View {
        FocumiHeroWorld(pet: nil)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

}

private struct CinematicGoalBeam: View {
    enum Style {
        case compact
        case prominent
        case spotlight
    }

    let goal: String
    var timeLabel: String?
    var timeValue: String?
    var style: Style = .prominent

    var body: some View {
        VStack(spacing: style == .prominent ? 8 : 4) {
            Text("What we're working on")
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.cocoonTextSecondary)

            Text(goal)
                .font(style == .prominent ? .title2.bold() : .headline)
                .fontDesign(.rounded)
                .foregroundStyle(Color.cocoonTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let timeLabel, let timeValue {
                Text(timeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cocoonTextSecondary)

                Text(timeValue)
                    .font(.system(.title, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.cocoonTextPrimary)
            }
        }
        .frame(maxWidth: style == .spotlight ? 176 : 440, alignment: .leading)
        .padding(.horizontal, style == .spotlight ? 0 : 18)
        .padding(.vertical, style == .prominent ? 15 : 10)
        .background {
            if style != .spotlight {
                Color.cocoonPaper.opacity(0.88)
                    .shadow(color: Color.cocoonTextPrimary.opacity(0.06), radius: 4, y: 2)
            }
        }
        .overlay(alignment: .topLeading) {
            if style != .spotlight {
                Rectangle()
                    .fill(Color.cocoonAccentSoft.opacity(0.72))
                    .frame(width: 42, height: 2)
                    .offset(x: 14, y: 7)
            }
        }
        .overlay(alignment: .bottom) {
            if style != .spotlight {
                Rectangle()
                    .fill(Color.cocoonStone.opacity(0.34))
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LocalDataRecoveryView: View {
    let model: FriendMVPModel

    @State private var showsFreshStartConfirmation = false

    var body: some View {
        ZStack {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.cocoonAccent)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Your journey is still here")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)

                Text("We couldn't open the saved journey on this iPhone. Nothing has been replaced. You can try again or choose a fresh start.")
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 480)

            VStack(spacing: 12) {
                Button("Try again") {
                    model.retryDataRecovery()
                }
                .buttonStyle(CocoonPrimaryButtonStyle())

                Button("Start a fresh journey") {
                    showsFreshStartConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(28)
        if showsFreshStartConfirmation {
            VintageDecisionOverlay(
                species: .cat,
                title: "Start a fresh journey?",
                message: "This clears the saved companion journey on this iPhone. Your current data stays unchanged until you confirm.",
                primaryTitle: "Clear local data and start fresh",
                cancelTitle: "Keep saved data",
                isDestructive: true,
                confirm: model.startFreshAfterDataRecovery,
                cancel: { showsFreshStartConfirmation = false }
            )
        }
        }
    }
}

private struct CompanionCocoonBackground: View {
    let pet: PetSpecies?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Keep the decorative room from competing with readable core content at
        // accessibility sizes. The foreground uses the same Approved Milo pose.
        FocumiHeroWorld(pet: dynamicTypeSize.isAccessibilitySize ? nil : pet)
            .ignoresSafeArea()
    }
}

/// A shared, original world-space reference for every app surface. The desk,
/// window light, book spine, and companion landing area are fixed by the
/// viewport rather than an image's alpha bounds, so page changes do not make
/// Milo or Max drift across the world.
private struct FocumiHeroWorld: View {
    let pet: PetSpecies?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let accent = pet == .dog ? Color.cocoonAccentSoft : Color.cocoonSage

            ZStack {
                // Background: aged-paper wall. This is intentionally fixed to the
                // viewport so the shared room does not drift with scrolling forms.
                Color.cocoonBackground
                HeroWorldWall(accent: accent, reduceTransparency: reduceTransparency)
                HeroWorldWindowLight(
                    accent: accent,
                    contrast: contrast,
                    reduceTransparency: reduceTransparency
                )
                VintagePaperGrain(tint: accent).padding(.horizontal, 18)

                // Midground: a stable desk horizon and book-spine reference.
                HeroWorldDesk(accent: accent, height: size.height * 0.42)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                HeroWorldBook(accent: accent)
                    .frame(width: min(size.width * 0.82, 450), height: min(size.height * 0.20, 168))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, max(20, size.height * 0.105))

                // Foreground stays sparse and decorative; functional UI always sits above it.
                HeroWorldForeground(accent: accent)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, max(16, size.height * 0.073))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct HeroWorldWall: View {
    let accent: Color
    let reduceTransparency: Bool

    var body: some View {
        LinearGradient(
            colors: [Color.cocoonPaper, Color.cocoonBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(Color.cocoonButter.opacity(reduceTransparency ? 0.08 : 0.18))
                .frame(width: 54)
                .rotationEffect(.degrees(-7), anchor: .topLeading)
                .offset(x: 20, y: -32)
        }
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(accent.opacity(reduceTransparency ? 0.05 : 0.09))
                .frame(width: 38)
                .rotationEffect(.degrees(7), anchor: .topTrailing)
                .offset(x: -36, y: -24)
        }
    }
}

private struct HeroWorldWindowLight: View {
    let accent: Color
    let contrast: ColorSchemeContrast
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            let windowWidth = min(proxy.size.width * 0.47, 250)
            let windowHeight = min(proxy.size.height * 0.27, 230)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.cocoonSurface.opacity(reduceTransparency ? 0.92 : 0.68))
                    .frame(width: windowWidth, height: windowHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(
                                accent.opacity(contrast == .increased ? 0.48 : 0.24),
                                lineWidth: contrast == .increased ? 1.5 : 1
                            )
                    }

                Rectangle()
                    .fill(accent.opacity(0.24))
                    .frame(width: 1, height: windowHeight)
                    .padding(.trailing, windowWidth * 0.50)

                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width - windowWidth * 0.83, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width - windowWidth * 0.05, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width - windowWidth * 1.14, y: proxy.size.height * 0.62))
                    path.addLine(to: CGPoint(x: proxy.size.width - windowWidth * 1.47, y: proxy.size.height * 0.52))
                    path.closeSubpath()
                }
                .fill(Color.cocoonButter.opacity(reduceTransparency ? 0.06 : 0.15))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 20)
            .padding(.trailing, 20)
            // Window light is composited as a background-only layer. It must
            // never change the rendering of an approved companion illustration.
            .compositingGroup()
        }
    }
}

private struct HeroWorldDesk: View {
    let accent: Color
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(accent.opacity(0.34)).frame(height: 2)
            LinearGradient(
                colors: [Color.cocoonStone.opacity(0.34), Color.cocoonButter.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Color.cocoonPaper.opacity(0.72))
                .frame(width: 72, height: 10)
                .rotationEffect(.degrees(-13))
                .offset(x: 30, y: 22)
        }
    }
}

private struct HeroWorldForeground: View {
    let accent: Color

    var body: some View {
        HStack(alignment: .bottom) {
            Capsule()
                .fill(Color.cocoonApricot.opacity(0.52))
                .frame(width: 9, height: 66)
                .rotationEffect(.degrees(-22), anchor: .bottom)
                .overlay(alignment: .top) {
                    Circle().fill(Color.cocoonButter).frame(width: 9, height: 9)
                }
            Spacer()
            VStack(spacing: 2) {
                Capsule().fill(accent.opacity(0.44)).frame(width: 31, height: 5)
                Capsule().fill(Color.cocoonStone.opacity(0.28)).frame(width: 46, height: 5)
            }
            .rotationEffect(.degrees(4))
        }
        .padding(.horizontal, 32)
    }
}

private struct HeroWorldBook: View {
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cocoonSurface.opacity(0.91))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accent.opacity(0.36), lineWidth: 1)
                }

            Rectangle()
                .fill(accent.opacity(0.38))
                .frame(width: 1.5)

            VStack(spacing: 8) {
                Capsule().fill(accent.opacity(0.24)).frame(width: 80, height: 1)
                Capsule().fill(accent.opacity(0.18)).frame(width: 126, height: 1)
                Capsule().fill(accent.opacity(0.16)).frame(width: 94, height: 1)
            }
        }
        .rotationEffect(.degrees(-2))
        .shadow(color: Color.cocoonTextPrimary.opacity(0.12), radius: 8, y: 4)
    }
}

@MainActor
private struct FocumiOpeningMoment: View {
    let reduceMotion: Bool
    let finish: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.cocoonBackground.ignoresSafeArea()
            DoublePawBrandMark(size: 224)
                .opacity(isVisible ? 1 : 0.32)
                .offset(y: isVisible ? 0 : 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CompanionPresentation.DoublePawBranding.accessibilityLabel)
        .task { @MainActor in
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            // Reduced Motion bypasses the transient presentation entirely.
            guard !reduceMotion else {
                finish()
                return
            }
            withAnimation(.easeOut(duration: 0.16)) {
                isVisible = true
            } completion: {
                // 0.16s fade in + 0.32s display + 0.18s fade out. This is
                // presentation-only, and never delays state restoration.
                withAnimation(.easeIn(duration: 0.18).delay(0.32)) {
                    isVisible = false
                } completion: {
                    finish()
                }
            }
        }
    }

}

private struct DoublePawBrandMark: View {
    let size: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: size * 0.16) {
            CatPawShape()
                .fill(Color.cocoonForest)
                .frame(width: size * 0.68, height: size)
            DogPawShape()
                .fill(Color.cocoonAccentSoft)
                .frame(width: size * 0.82, height: size)
        }
        .frame(width: size * 1.66, height: size)
        .accessibilityHidden(true)
    }
}

private struct CatPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let unit = min(rect.width / 1.36, rect.height / 1.72)
        let centerX = rect.midX
        let baseY = rect.maxY - unit * 0.78
        path.addEllipse(in: CGRect(x: centerX - unit * 0.50, y: baseY, width: unit, height: unit * 0.78))
        for (x, y, size) in [(-0.48, -0.50, 0.34), (-0.16, -0.70, 0.36), (0.18, -0.70, 0.36), (0.50, -0.50, 0.34)] {
            path.addEllipse(in: CGRect(
                x: centerX + x * unit - size * unit / 2,
                y: baseY + y * unit - size * unit / 2,
                width: size * unit,
                height: size * unit
            ))
        }
        return path
    }
}

private struct DogPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let unit = min(rect.width / 1.54, rect.height / 1.82)
        let centerX = rect.midX
        let baseY = rect.maxY - unit * 0.84
        path.addRoundedRect(
            in: CGRect(x: centerX - unit * 0.62, y: baseY, width: unit * 1.24, height: unit * 0.84),
            cornerSize: CGSize(width: unit * 0.36, height: unit * 0.36)
        )
        for (x, y, width, height) in [(-0.57, -0.50, 0.34, 0.42), (-0.20, -0.70, 0.37, 0.46), (0.20, -0.70, 0.37, 0.46), (0.57, -0.50, 0.34, 0.42)] {
            path.addEllipse(in: CGRect(
                x: centerX + x * unit - width * unit / 2,
                y: baseY + y * unit - height * unit / 2,
                width: width * unit,
                height: height * unit
            ))
        }
        return path
    }
}

private struct VintagePaperBackdrop: View {
    let treatment: CinematicFocusBeam.Treatment

    var body: some View {
        FocumiHeroWorld(pet: treatment == .completion ? .cat : nil)
        .accessibilityHidden(true)
    }
}

/// Static, low-contrast editorial paper texture. It is deliberately not animated so it
/// remains quiet at 60 fps and disappears from the accessibility tree.
private struct VintagePaperGrain: View {
    let tint: Color

    var body: some View {
        VStack(spacing: 22) {
            ForEach(0..<18, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(0..<17, id: \.self) { column in
                        Circle()
                            .fill(tint.opacity((row + column).isMultiple(of: 5) ? 0.09 : 0.035))
                            .frame(width: (row + column).isMultiple(of: 4) ? 1.4 : 0.8)
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : 8)
            }
        }
        .opacity(0.72)
        .accessibilityHidden(true)
    }
}

/// A small original line-icon set for functional companion surfaces. These are made
/// from primitive SwiftUI shapes so they stay crisp at Dynamic Type sizes and never
/// introduce a borrowed illustration or an SF Symbol into the editorial UI.
struct FocumiCompanionIcon: View {
    let kind: FocumiCompanionIconKind
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            switch kind {
            case .bookmarkPaw:
                bookmark
            case .pageTurn:
                pageTurn
            case .companionClock:
                companionClock
            case .pencilBloom:
                pencilBloom
            case .scarfBow:
                scarfBow
            case .pawStamp:
                pawStamp
            case .settingsPage:
                settingsPage
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: max(1.5, size * 0.09), lineCap: .round, lineJoin: .round)
    }

    private var bookmark: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.27, y: size * 0.12))
                path.addLine(to: CGPoint(x: size * 0.73, y: size * 0.12))
                path.addLine(to: CGPoint(x: size * 0.73, y: size * 0.86))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.68))
                path.addLine(to: CGPoint(x: size * 0.27, y: size * 0.86))
                path.closeSubpath()
            }
            .stroke(tint, style: stroke)
            Circle().fill(tint).frame(width: size * 0.13, height: size * 0.13).offset(x: -size * 0.12, y: -size * 0.18)
            Circle().fill(tint).frame(width: size * 0.13, height: size * 0.13).offset(x: size * 0.12, y: -size * 0.18)
            Circle().fill(tint).frame(width: size * 0.11, height: size * 0.11).offset(y: -size * 0.02)
        }
    }

    private var pageTurn: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .stroke(tint, style: stroke)
                .padding(size * 0.15)
            Path { path in
                path.move(to: CGPoint(x: size * 0.52, y: size * 0.22))
                path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.22))
                path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.45))
                path.closeSubpath()
            }
            .stroke(tint, style: stroke)
        }
    }

    private var companionClock: some View {
        ZStack {
            Circle().stroke(tint, style: stroke).padding(size * 0.12)
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.31))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.64, y: size * 0.58))
            }
            .stroke(tint, style: stroke)
            Circle().fill(tint).frame(width: size * 0.1, height: size * 0.1).offset(x: -size * 0.35, y: -size * 0.34)
            Circle().fill(tint).frame(width: size * 0.1, height: size * 0.1).offset(x: size * 0.35, y: -size * 0.34)
        }
    }

    private var pencilBloom: some View {
        ZStack {
            Capsule().fill(tint).frame(width: size * 0.14, height: size * 0.72).rotationEffect(.degrees(42))
            Circle().stroke(tint, style: stroke).frame(width: size * 0.27, height: size * 0.27).offset(x: size * 0.25, y: -size * 0.25)
            Circle().fill(tint).frame(width: size * 0.09, height: size * 0.09).offset(x: size * 0.25, y: -size * 0.25)
        }
    }

    private var scarfBow: some View {
        ZStack {
            Ellipse().stroke(tint, style: stroke).frame(width: size * 0.42, height: size * 0.28).offset(x: -size * 0.18)
            Ellipse().stroke(tint, style: stroke).frame(width: size * 0.42, height: size * 0.28).offset(x: size * 0.18)
            Circle().fill(tint).frame(width: size * 0.16, height: size * 0.16)
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.57))
                path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.85))
                path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.85))
                path.closeSubpath()
            }.fill(tint)
        }
    }

    private var pawStamp: some View {
        ZStack {
            Circle().stroke(tint, style: stroke).padding(size * 0.08)
            Circle().fill(tint).frame(width: size * 0.26, height: size * 0.2).offset(y: size * 0.12)
            ForEach([-0.22, 0, 0.22], id: \.self) { x in
                Circle().fill(tint).frame(width: size * 0.13, height: size * 0.16).offset(x: size * x, y: -size * 0.17)
            }
        }
    }

    private var settingsPage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                .stroke(tint, style: stroke)
                .padding(size * 0.16)
            Path { path in
                path.move(to: CGPoint(x: size * 0.36, y: size * 0.43))
                path.addLine(to: CGPoint(x: size * 0.64, y: size * 0.43))
                path.move(to: CGPoint(x: size * 0.36, y: size * 0.61))
                path.addLine(to: CGPoint(x: size * 0.57, y: size * 0.61))
            }
            .stroke(tint, style: stroke)
            Path { path in
                path.move(to: CGPoint(x: size * 0.62, y: size * 0.16))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.16))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.42))
                path.closeSubpath()
            }
            .fill(tint.opacity(0.35))
        }
    }
}

private struct VintagePaperCard<Content: View>: View {
    let tint: Color
    let tab: LocalizedStringKey?
    let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(tint: Color = .cocoonAccentSoft, tab: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.tab = tab
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 16)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(tint.opacity(0.58))
                    .frame(height: 1)
                    .padding(.horizontal, -14)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                // Decorative tabs deliberately yield at accessibility sizes so a long
                // localized label never collides with the functional card content.
                if let tab, !dynamicTypeSize.isAccessibilitySize {
                    Text(tab)
                        .font(.caption2.bold().smallCaps())
                        .fontDesign(.serif)
                        .foregroundStyle(Color.cocoonTextPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.24), in: Capsule())
                        .offset(x: 4, y: -12)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct PetOnboardingView: View {
    @Binding var petName: String
    let adopt: (PetSpecies) -> Void
    let settingsAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedSpecies: PetSpecies

    init(
        petName: Binding<String>,
        adopt: @escaping (PetSpecies) -> Void,
        settingsAction: @escaping () -> Void,
        initialSpecies: PetSpecies = .cat
    ) {
        _petName = petName
        self.adopt = adopt
        self.settingsAction = settingsAction
        _selectedSpecies = State(initialValue: initialSpecies)
    }

    var body: some View {
        ZStack {
            Color.cocoonBackground
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 20 : 28) {
                    Text("Choose your focus companion")
                        .font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .largeTitle.bold())
                        .fontDesign(.serif)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(FocumiCorePreviewAnchor.top)
                    MiloStaticPoseView(
                        species: selectedSpecies,
                        mood: .welcome,
                        size: dynamicTypeSize.isAccessibilitySize ? 140 : 300,
                        accessibilityLabel: "\(CompanionPresentation.displayName(for: selectedSpecies))，正在等你一起开始。"
                    )
                    Picker("伙伴", selection: $selectedSpecies) {
                        Text("Milo").tag(PetSpecies.cat)
                        Text("Max").tag(PetSpecies.dog)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("focumi.pet-choice")
                    Text("\(CompanionPresentation.displayName(for: selectedSpecies)) will quietly stay with you for the next thing.")
                        .font(dynamicTypeSize.isAccessibilitySize ? .body : .title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { adopt(selectedSpecies) } label: {
                        FocumiPawActionLabel("Begin with \(CompanionPresentation.displayName(for: selectedSpecies))")
                    }
                        .buttonStyle(FocumiFlowPrimaryButtonStyle())
                        .accessibilityLabel("Begin with \(CompanionPresentation.displayName(for: selectedSpecies))")
                        .accessibilityHint("确认伙伴后进入任务设置")
                        .id(FocumiCorePreviewAnchor.bottom)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                }
                .task { await FocumiCorePreviewAnchor.scrollIfRequested(using: proxy) }
                .safeAreaInset(edge: .top, spacing: 0) {
                    FocumiTopControlRow(
                        showsBack: false,
                        backAction: {},
                        settingsAction: settingsAction
                    )
                }
            }
        }
    }

}

private struct FocumiTopControlRow: View {
    let showsBack: Bool
    let backAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack {
            if showsBack {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.cocoonTextPrimary)
                .background(Color.cocoonSurface.opacity(0.92), in: Circle())
                .contentShape(Circle())
                .accessibilityLabel("返回认识 Milo")
                .accessibilityHint("返回 Milo 伙伴确认")
                .accessibilityIdentifier("focumi.return-to-meet-milo")
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Button(action: settingsAction) {
                Image(systemName: "gearshape")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.cocoonTextPrimary)
            .background(Color.cocoonSurface.opacity(0.92), in: Circle())
            .contentShape(Circle())
            .accessibilityLabel("设置")
            .accessibilityIdentifier("focumi.settings")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }
}

private struct PetOnboardingHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 10) {
            Text("Meet your focus companion")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .title.bold())
                .fontDesign(.serif)
                .multilineTextAlignment(.center)

            Text("Choose a companion who stays with you while Screen Time helps block distracting apps.")
                .font(dynamicTypeSize.isAccessibilitySize ? .footnote : .subheadline)
                .foregroundStyle(Color.cocoonTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PetOnboardingFooter: View {
    @Binding var petName: String
    let create: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name your companion")
                .font(.headline)

            TextField("Name your companion", text: $petName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(
                    colorScheme == .dark
                        ? Color(uiColor: .secondarySystemGroupedBackground)
                        : Color.cocoonSurface
                )
                .clipShape(.rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cocoonStone.opacity(0.48), lineWidth: 1)
                }

            Button("Create companion", action: create)
                .buttonStyle(CocoonPrimaryButtonStyle())
        }
        .padding(.top, 2)
        .frame(maxWidth: 520)
    }
}

private struct PetChoiceLayout: View {
    @Binding var selection: PetSpecies
    let avatarSize: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        layout {
            ForEach(PetSpecies.allCases) { species in
                PetChoiceCard(
                    species: species,
                    isSelected: selection == species,
                    avatarSize: avatarSize,
                    select: { select(species) }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 520)
    }

    private func select(_ species: PetSpecies) {
        selection = species
    }
}

private struct PetChoiceCard: View {
    let species: PetSpecies
    let isSelected: Bool
    let avatarSize: CGFloat
    let select: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                PetAvatarView(species: species, mood: .welcome, size: avatarSize)

                HStack(spacing: 7) {
                    Text(CompanionPresentation.displayName(for: species))
                        .font(.title3.bold())
                        .fontDesign(.rounded)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(species.editorialAccent)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: avatarSize + 72)
            .contentShape(.rect)
            .background(
                isSelected
                    ? species.editorialAccent.opacity(0.12)
                    : (colorScheme == .dark
                        ? Color(uiColor: .secondarySystemGroupedBackground)
                        : Color.cocoonSurface)
            )
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? species.editorialAccent : .clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(species.choiceAccessibilityLabel)
        .accessibilityInputLabels(species.voiceControlLabels)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FocusSetupMVPView: View {
    let model: FriendMVPModel

    @FocusState private var isGoalFocused: Bool
    @State private var showsFreeFocusConfirmation = ProcessInfo.processInfo.arguments.contains(
        "--friend-mvp-preview-free-focus-alert"
    )
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var petSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 104 : 128
    }

    var body: some View {
        @Bindable var model = model

        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 10 : 12) {
                    FocusSetupHeader(
                        species: model.snapshot.pet ?? .cat,
                        petName: model.presentedPetName,
                        petSize: petSize
                    )
                    .id(FocusSetupScrollAnchor.top)

                    HomeAmbienceControl(
                        isEnabled: model.preferences.musicEnabled,
                        playbackState: model.musicPlaybackState,
                        toggle: { model.setMusicEnabled(!model.preferences.musicEnabled) }
                    )

                    FocusSetupForm(
                        goal: $model.goalDraft,
                        duration: $model.durationDraft,
                        isGoalFocused: $isGoalFocused
                    )

                    ScreenTimeSetupPanel(model: model)

                    FocusSetupPrimaryButton(
                        petName: model.presentedPetName,
                        isEnabled: model.canStart || FocusSetupPreview.isReady
                    ) {
                        isGoalFocused = false
                        if model.needsFreeFocusConfirmation {
                            showsFreeFocusConfirmation = true
                        } else {
                            Task { await model.startSession() }
                        }
                    }
                    .id(FocusSetupScrollAnchor.middle)

                    Color.clear
                        .frame(height: 1)
                        .id(FocusSetupScrollAnchor.bottom)

                        }
                        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 20)
                        .padding(.top, 12)
                        // The CTA remains an ordinary item in the scroll view.  This lets
                        // SwiftUI reserve its real height instead of letting a fixed footer
                        // cover the last Screen Time setting at accessibility text sizes.
                        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 36 : 24)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                }
                .task {
                    await scrollToDebugPreviewAnchor(using: scrollProxy)
                }
            }
        .navigationTitle("Start together")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.durationDraft) {
            model.setPreferredDuration(model.durationDraft)
        }
        if showsFreeFocusConfirmation {
            VintageDecisionOverlay(
                species: model.snapshot.pet ?? .cat,
                title: "Start without a goal?",
                message: "That's okay. You and \(CompanionPresentation.displayName(for: model.snapshot.pet, storedName: model.snapshot.petName)) can simply focus together this time.",
                primaryTitle: "Start free focus",
                cancelTitle: "Add a goal",
                confirm: { Task { await model.startSession(allowFreeFocus: true) } },
                cancel: { isGoalFocused = true; showsFreeFocusConfirmation = false }
            )
        }
        }
    }

    private func scrollToDebugPreviewAnchor(using proxy: ScrollViewProxy) async {
#if DEBUG
        guard let anchor = FocusSetupScrollAnchor.debugLaunchAnchor else { return }
        // Wait for Dynamic Type layout to finish before resolving the named target. This is
        // screenshot-only coverage plumbing and is absent from release behavior.
        for _ in 0..<2 {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.none) {
                proxy.scrollTo(anchor, anchor: anchor == .bottom ? .bottom : .top)
            }
        }
#endif
    }
}

private enum FocusSetupScrollAnchor: String, Hashable {
    case top
    case middle
    case bottom

    #if DEBUG
    static var debugLaunchAnchor: Self? {
        guard let rawValue = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--friend-mvp-preview-scroll=") })?
            .split(separator: "=", maxSplits: 1)
            .last
        else { return nil }

        return Self(rawValue: String(rawValue))
    }
    #endif
}

/// DEBUG-only presentation override for deterministic screenshot coverage. It never mutates
/// Screen Time authorization or a FamilyActivitySelection; release builds only read capability.
private enum FocusSetupPreview {
    static var isReady: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--friend-mvp-preview-ready")
#else
        false
#endif
    }

    static var selectedAppCount: Int? {
#if DEBUG
        isReady ? 13 : nil
#else
        nil
#endif
    }
}

private struct FocusSetupHeader: View {
    let species: PetSpecies
    let petName: String
    let petSize: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 18 : 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: 520)
        .background {
            Ellipse()
                .fill(species.editorialAccent.opacity(0.12))
                .frame(height: petSize * 0.94)
                .offset(x: -petSize * 0.52)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cocoonAccentSoft.opacity(0.5))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            if !dynamicTypeSize.isAccessibilitySize {
                VintageEditorialKicker(title: "Today’s page", symbol: "book.closed.fill")
                    .padding(.leading, 14)
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            PetAvatarView(
                species: species,
                mood: .welcome,
                size: petSize,
                activity: .forPhase(.setup),
                accessibilityName: petName
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Start together with \(petName)")
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("What would you like to finish with \(petName) today?")
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    FocumiCompanionIcon(kind: .bookmarkPaw, tint: .cocoonSage, size: 16)
                    Text("A few fewer interruptions, one page at a time.")
                }
                    .font(.caption)
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // This is a companion identity cue, not the accessibility-size hero. Keeping
                // it compact preserves room for the goal and the actionable setup fields.
                PetAvatarView(
                    species: species,
                    mood: .welcome,
                    size: 64,
                    activity: .forPhase(.setup),
                    accessibilityName: petName
                )
                .accessibilitySortPriority(1)

                Text("Start together with \(petName)")
                    // This title is editorial context rather than the form's task.  At
                    // accessibility sizes it deliberately sits below the goal, settings,
                    // and primary action in visual weight without capping their text size.
                    .font(.headline.bold())
                    .fontDesign(.rounded)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilitySortPriority(4)
            }

            Text("What would you like to finish with \(petName) today?")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilitySortPriority(3)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                FocumiCompanionIcon(kind: .bookmarkPaw, tint: .cocoonSage, size: 16)
                Text("A few fewer interruptions, one page at a time.")
            }
            .font(.caption2)
            .foregroundStyle(Color.cocoonTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilitySortPriority(2)
        }
    }
}

private struct HomeAmbienceControl: View {
    let isEnabled: Bool
    let playbackState: FocusAudioPlaybackState
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                FocumiCompanionIcon(kind: .pencilBloom, tint: .cocoonAccentSoft, size: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Home ambience")
                        .font(.subheadline.weight(.semibold))
                    if isEnabled {
                        Text(playbackDescription)
                            .font(.caption)
                    } else {
                        Text("Off")
                            .font(.caption)
                    }
                }
                Spacer(minLength: 8)
                Text(isEnabled ? "Enabled" : "Off")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isEnabled ? Color.cocoonAccent : Color.cocoonTextSecondary)
            }
            .foregroundStyle(Color.cocoonTextPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.cocoonSurfaceSoft, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 520)
        .accessibilityLabel("Home ambience")
        .accessibilityValue(isEnabled ? playbackDescriptionText : String(localized: "Off"))
        .accessibilityHint(isEnabled ? "Turn off music" : "Play music")
    }

    private var playbackDescription: LocalizedStringResource {
        switch playbackState {
        case .stopped: "Music is preparing"
        case .preparing: "Music is preparing"
        case .playing: "Music is playing"
        case .interrupted: "Music is paused by iPhone"
        case .failed: "Music could not start"
        }
    }

    private var playbackDescriptionText: String {
        String(localized: playbackDescription)
    }
}

private struct FocusSetupForm: View {
    @Binding var goal: String
    @Binding var duration: TimeInterval
    let isGoalFocused: FocusState<Bool>.Binding

    var body: some View {
        VintagePaperCard(tint: .cocoonAccentSoft, tab: "Today’s page") {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FocumiCompanionIcon(kind: .pencilBloom, tint: .cocoonAccent, size: 20)
                Text("What are we working on?")
                    .font(.headline)
            }

            TextField("For example: finish chapter three", text: $goal)
                .focused(isGoalFocused)
                .submitLabel(.done)
                .onSubmit { isGoalFocused.wrappedValue = false }
                .foregroundStyle(Color.cocoonTextPrimary)
                .tint(Color.cocoonAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .background(Color.cocoonSurfaceSoft)
                .clipShape(.rect(cornerRadius: 15))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.cocoonStone.opacity(0.52), lineWidth: 1)
                }

            HStack(spacing: 8) {
                FocumiCompanionIcon(kind: .companionClock, tint: .cocoonAccentSoft, size: 20)
                Text("How long shall we focus together?")
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 8) {
                DurationChoice(minutes: 30, duration: $duration)
                DurationChoice(minutes: 45, duration: $duration)
                DurationChoice(minutes: 60, duration: $duration)
                DurationChoice(minutes: 120, duration: $duration)
            }
        }
        }
        .frame(maxWidth: 520)
    }
}

private struct DurationChoice: View {
    let minutes: Int
    @Binding var duration: TimeInterval
    @Environment(\.locale) private var locale

    private var isSelected: Bool { duration == TimeInterval(minutes * 60) }

    var body: some View {
        Button {
            duration = TimeInterval(minutes * 60)
        } label: {
            Text(FocusPresentationCopy.durationLabel(minutes: minutes, locale: locale))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(isSelected ? Color.white : Color.cocoonTextPrimary)
                .background(isSelected ? Color.cocoonAccent : Color.cocoonSurfaceSoft)
                .clipShape(.rect(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ScreenTimeSetupPanel: View {
    let model: FriendMVPModel
    var isEditorial: Bool = false
    @Environment(\.locale) private var locale

    @State private var showsPermissionExplanation: Bool = {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains(
            "--friend-mvp-preview-permission-explanation"
        )
#else
        false
#endif
    }()

    var body: some View {
        Group {
        if isEditorial {
            editorialReadinessRow
        } else {
            VintagePaperCard(tint: .cocoonSage, tab: "Fewer interruptions") {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    FocumiCompanionIcon(kind: readiness.iconKind, tint: .cocoonSage, size: 22)
                    Text("A little less interruption")
                        .font(.headline)
                }

                readinessContent

                Text("When focus begins, Focumi asks iPhone to temporarily limit the apps you selected.")
                    .font(.caption)
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            }
            .frame(maxWidth: 520)
        }
        }
        .sheet(isPresented: $showsPermissionExplanation) {
            ScreenTimePermissionExplanationView(
                continueAction: {
                    showsPermissionExplanation = false
                    Task { await model.requestAuthorization() }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var editorialReadinessRow: some View {
        switch readiness {
        case .needsScreenTime:
            Button { showsPermissionExplanation = true } label: {
                Label("Limit selected apps during focus", systemImage: "nosign")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("设置屏幕使用时间后即可开始专注。")
        case .needsApps:
            Button { model.capability.isPickerPresented = true } label: {
                Label("Choose apps to limit during focus", systemImage: "nosign")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        case .ready(let selectedApps):
            Button { model.capability.isPickerPresented = true } label: {
                Label("Limit \(selectedApps) apps during focus", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var authorizationReady: Bool {
        FocusSetupPreview.isReady || model.capability.authorizationState == .approved
    }

    private var selectedAppsReady: Bool {
        model.capability.selectedItemCount > 0
    }

    private var readiness: FocusPactReadinessPresentation {
        .make(
            isScreenTimeApproved: authorizationReady,
            selectedAppCount: FocusSetupPreview.selectedAppCount ?? model.capability.selectedItemCount
        )
    }

    @ViewBuilder
    private var readinessContent: some View {
        switch readiness {
        case .needsScreenTime:
            CompactReadinessAction(
                title: "Set up Screen Time",
                detail: "Needed before we begin",
                iconKind: .pageTurn,
                action: { showsPermissionExplanation = true }
            )
        case .needsApps:
            CompactReadinessAction(
                title: "Choose distracting apps",
                detail: "Screen Time is ready",
                iconKind: .bookmarkPaw,
                action: { model.capability.isPickerPresented = true }
            )
        case .ready(let selectedApps):
            Button { model.capability.isPickerPresented = true } label: {
                HStack(spacing: 9) {
                    FocumiCompanionIcon(kind: .pawStamp, tint: .cocoonSage, size: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Screen Time is ready")
                            .font(.subheadline.weight(.semibold))
                        Text(FocusPresentationCopy.selectedDistractingApps(count: selectedApps, locale: locale))
                            .font(.caption)
                            .foregroundStyle(Color.cocoonTextSecondary)
                    }
                    Spacer(minLength: 8)
                    FocumiCompanionIcon(kind: .pageTurn, tint: .cocoonAccentSoft, size: 16)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Screen Time is ready. \(FocusPresentationCopy.selectedDistractingApps(count: selectedApps, locale: locale)).")
            .accessibilityHint("Opens the app selection.")
        }
    }
}

private struct CompactReadinessAction: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let iconKind: FocumiCompanionIconKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                FocumiCompanionIcon(kind: iconKind, tint: .cocoonAccentSoft, size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(Color.cocoonTextSecondary)
                }
                Spacer(minLength: 8)
                FocumiCompanionIcon(kind: .pageTurn, tint: .cocoonAccentSoft, size: 16)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct ScreenTimePermissionExplanationView: View {
    let continueAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.cocoonAccent)
                            .accessibilityHidden(true)

                        Text("You choose what to protect")
                            .font(.title2.bold())
                            .fontDesign(.rounded)

                        Text("Screen Time permission lets Focumi place Apple's protection screen over only the distracting apps you select.")
                            .foregroundStyle(Color.cocoonTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        PrivacyPromiseRow(
                            symbol: "checkmark.shield.fill",
                            text: "Only apps you select are protected."
                        )
                        PrivacyPromiseRow(
                            symbol: "eye.slash.fill",
                            text: "We cannot read messages, posts, searches, or browsing content."
                        )
                        PrivacyPromiseRow(
                            symbol: "iphone.gen3",
                            text: "Your companion and beta activity stay on this iPhone."
                        )
                        PrivacyPromiseRow(
                            symbol: "trash.fill",
                            text: "You can remove permission or clear local data whenever you want."
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Continue to Screen Time", action: continueAction)
                    .buttonStyle(CocoonPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }
            .navigationTitle("Before you continue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }
}

private struct PrivacyPromiseRow: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.cocoonSage)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            Text(text)
                .foregroundStyle(Color.cocoonTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FocusSetupPrimaryButton: View {
    let petName: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("Start together with \(petName)")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color.cocoonAccent)
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: Color.cocoonAccent.opacity(0.24), radius: 10, y: 5)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .contentShape(.rect)
        .accessibilityLabel("Focus together")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isEnabled)
    }

}

private struct FocusSessionMVPView: View {
    let model: FriendMVPModel

    @State private var endConfirmation = FocusEndConfirmationState(
        isPresented: ProcessInfo.processInfo.arguments.contains(
            "--friend-mvp-preview-end-confirmation"
        )
    )

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remainingFocusTime(at: context.date)

            ZStack {
                // Focus intentionally opts out of the shared room's window beams and
                // paper strips. The working surface needs one quiet paper plane so
                // the goal, companion, and clock remain the visual hierarchy.
                FocusQuietPaperBackdrop()

                ScrollView {
                    VStack(spacing: 20) {
                        FocusGoalSummary(
                            goal: model.snapshot.goal,
                            petName: model.presentedPetName
                        )
                            .accessibilitySortPriority(4)

                        FocusProgressPet(
                            species: model.snapshot.pet ?? .cat,
                            petName: model.presentedPetName,
                            size: 296
                        )
                        .accessibilitySortPriority(0)

                        FocusTimeRemaining(
                            remaining: remaining,
                            musicEnabled: model.preferences.musicEnabled,
                            musicPlaybackState: model.musicPlaybackState,
                            toggleMusic: {
                                model.setMusicEnabled(!model.preferences.musicEnabled)
                            }
                        )
                        .accessibilitySortPriority(3)

                        if model.capability.needsFocusProtectionWarning {
                            FocusProtectionWarning()
                                .accessibilitySortPriority(2)
                        }

                        Button("End for now") {
                            endConfirmation.request()
                        }
                        .buttonStyle(CocoonSecondaryButtonStyle())
                        .accessibilitySortPriority(1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaPadding(.top, 28)
                .safeAreaPadding(.bottom, 18)

                if endConfirmation.isPresented {
                    FocusEndConfirmationOverlay(
                        species: model.snapshot.pet ?? .cat,
                        petName: model.presentedPetName,
                        continueFocusing: { endConfirmation.continueFocusing() },
                        confirmEnd: {
                            guard endConfirmation.confirmEnd() else { return }
                            model.endSession()
                        }
                    )
                }
            }
            .onChange(of: context.date) {
                model.reconcile(at: context.date)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

/// Focus has a deliberately plain background. The shared grain remains just
/// perceptible, but no room beam, tab, stitch, or foreground decoration
/// competes with the session facts.
private struct FocusQuietPaperBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Dark appearance is still warm paper rather than a brown-black
            // filter: this keeps the companion readable without creating a
            // second visual language.
            colorScheme == .dark
                ? Color(red: 0.30, green: 0.22, blue: 0.18)
                : Color.cocoonBackground
            VintagePaperGrain(tint: .cocoonAccentSoft)
                .opacity(reduceTransparency ? 0.035 : 0.10)
                .padding(.horizontal, 30)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct FocusGoalSummary: View {
    let goal: String
    let petName: String

    var body: some View {
        VStack(spacing: 6) {
            Text("\(petName) is here, working on this with you")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cocoonTextSecondary)
                .accessibilityHidden(true)

            Text(goal)
                .font(.title2.bold())
                .fontDesign(.serif)
                .foregroundStyle(Color.cocoonTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(goal)
    }
}

private struct FocusProgressPet: View {
    let species: PetSpecies
    let petName: String
    let size: CGFloat

    var body: some View {
        PetAvatarView(
            species: species,
            mood: .focusing,
            size: size,
            activity: .forPhase(.focusing),
            accessibilityName: petName,
            repeatsAnimation: false
        )
        .frame(width: size, height: size * 0.84)
        .frame(maxWidth: 440)
        .compositingGroup()
    }
}

private struct FocusTimeRemaining: View {
    let remaining: TimeInterval
    let musicEnabled: Bool
    let musicPlaybackState: FocusAudioPlaybackState
    let toggleMusic: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 50

    var body: some View {
        VStack(spacing: 9) {
            Text("Remaining focus time")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cocoonTextSecondary)

            Group {
                if reduceMotion {
                    Text(timeString(remaining))
                } else {
                    Text(timeString(remaining))
                        .contentTransition(.numericText())
                }
            }
            .font(.system(size: timerSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.cocoonTextPrimary)
            .contentTransition(reduceMotion ? .identity : .numericText())

            Button(action: toggleMusic) {
                Label(
                    musicActionTitle,
                    systemImage: musicActionSymbol
                )
                .font(.subheadline.weight(.semibold))
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .foregroundStyle(isActivelyPlaying ? Color.cocoonSurface : Color.cocoonAccent)
                .background(
                    isActivelyPlaying ? Color.cocoonAccent : Color.cocoonSurfaceSoft,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
            .accessibilityValue(musicAccessibilityValue)
        }
        .frame(maxWidth: 520)
        .accessibilityElement(children: .contain)
    }

    private var musicAccessibilityValue: LocalizedStringResource {
        switch musicPlaybackState {
        case .stopped: "Music is off"
        case .preparing: "Music is preparing"
        case .playing: "Music is playing"
        case .interrupted: "Music is paused by iPhone"
        case .failed: "Music could not start"
        }
    }

    private var musicActionTitle: LocalizedStringKey {
        musicEnabled ? "Turn off music" : "Play music"
    }

    private var musicActionSymbol: String {
        if !musicEnabled { return "music.note" }
        return "pause.fill"
    }

    private var isActivelyPlaying: Bool {
        musicPlaybackState == .playing
    }
}

private struct FocusProtectionWarning: View {
    var body: some View {
        Text("Focumi could not confirm iPhone protection. Check Screen Time authorization and try again.")
            .font(.caption2)
            .foregroundStyle(Color.cocoonTextSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
            .accessibilityElement(children: .combine)
    }
}

private struct FocusEndConfirmationOverlay: View {
    let species: PetSpecies
    let petName: String
    let continueFocusing: () -> Void
    let confirmEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var continueFocusIsFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.cocoonTextPrimary.opacity(0.24)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
            VStack(spacing: 16) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        confirmationPet
                        confirmationText
                    }
                        .multilineTextAlignment(.center)
                } else {
                    HStack(spacing: 16) {
                        confirmationPet
                        confirmationText
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: 430, alignment: .leading)
                }

                    VStack(spacing: 10) {
                        Button("Continue focusing with \(petName)", action: continueFocusing)
                            .buttonStyle(CocoonPrimaryButtonStyle())
                            .accessibilityFocused($continueFocusIsFocused)
                            .accessibilityHint("Dismisses this confirmation and keeps the current focus session running.")

                        Button("End for now", action: confirmEnd)
                            .buttonStyle(CocoonDangerButtonStyle())
                            .accessibilityHint("Ends this focus session. Focumi will stop requesting limits for the selected apps.")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // Keep the normal confirmation card compact; at accessibility sizes this
            // remains a scroll container instead of growing into an empty full sheet.
            .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 640 : 370, alignment: .bottom)
            .safeAreaPadding(.top, 18)
            .safeAreaPadding(.bottom, 18)
            .background(Color.cocoonSurface, in: UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 30,
                style: .continuous
            ))
            .overlay(alignment: .top) {
                VintageEditorialKicker(title: "Bookmark this page", symbol: "bookmark.fill")
                    .padding(.top, 12)
                    .accessibilityHidden(true)
            }
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous)
                    .strokeBorder(Color.cocoonAccentSoft.opacity(0.65), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, continueFocusing)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            continueFocusIsFocused = true
        }
    }

    private var confirmationPet: some View {
        PetAvatarView(
            species: species,
            mood: .waiting,
            size: 124,
            activity: .waiting,
            accessibilityName: petName,
            repeatsAnimation: false
        )
        .accessibilityHidden(true)
    }

    private var confirmationText: some View {
        VStack(spacing: 8) {
            Text("Pause for now?")
                .font(.title2.bold())
                .fontDesign(.rounded)
            Text("This page will stay here. When you’re ready, you and \(petName) can begin again.")
                .font(.body)
                .foregroundStyle(Color.cocoonTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VintageDecisionOverlay: View {
    let species: PetSpecies
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let cancelTitle: LocalizedStringKey
    var isDestructive = false
    var showsEditorialKicker = true
    let confirm: () -> Void
    let cancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var primaryIsFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.cocoonTextPrimary.opacity(0.24).ignoresSafeArea().accessibilityHidden(true)
            ScrollView {
            VStack(spacing: 14) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        decisionPet
                        decisionText
                    }
                    .multilineTextAlignment(.center)
                } else {
                    HStack(spacing: 16) {
                        decisionPet
                        decisionText.multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: 430, alignment: .leading)
                }
                if isDestructive {
                    Button(primaryTitle, action: confirm)
                        .buttonStyle(CocoonDangerButtonStyle())
                        .accessibilityFocused($primaryIsFocused)
                } else {
                    Button(primaryTitle, action: confirm)
                        .buttonStyle(CocoonPrimaryButtonStyle())
                        .accessibilityFocused($primaryIsFocused)
                }
                Button(cancelTitle, action: cancel)
                    .buttonStyle(CocoonSecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // Match the end-session card: compact at standard type, scrollable at AXXXL.
            .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 640 : 370, alignment: .bottom)
            .safeAreaPadding(.top, 18)
            .safeAreaPadding(.bottom, 18)
            .background(Color.cocoonSurface, in: UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous))
            .overlay(alignment: .top) {
                if showsEditorialKicker {
                    VintageEditorialKicker(title: "Keep this note", symbol: "bookmark.fill")
                        .padding(.top, 12)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous)
                    .strokeBorder(Color.cocoonAccentSoft.opacity(0.65), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, cancel)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .onAppear { primaryIsFocused = true }
    }

    private var decisionPet: some View {
        PetAvatarView(species: species, mood: .waiting, size: 116, activity: .waiting, repeatsAnimation: false)
            .accessibilityHidden(true)
    }

    private var decisionText: some View {
        VStack(spacing: 8) {
            Text(title).font(.title3.bold()).fontDesign(.serif)
            Text(message).font(.body).foregroundStyle(Color.cocoonTextSecondary)
        }
    }
}

private struct GoalCapsule: View {
    let goal: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .foregroundStyle(Color.cocoonAccent)
                .accessibilityHidden(true)
            Text(goal)
                .font(.headline)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 440)
        .background(Color.cocoonSurface)
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.cocoonStone.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

private struct AccessRequestMVPView: View {
    let model: FriendMVPModel

    @FocusState private var isCustomReasonFocused: Bool

    var body: some View {
        @Bindable var model = model

        GeometryReader { proxy in
            let petSize = min(112, max(88, proxy.size.height * 0.13))

            VStack(spacing: 0) {
                AccessRequestHeader(
                    species: model.snapshot.pet ?? .cat,
                    petName: model.presentedPetName,
                    goal: model.snapshot.goal,
                    petSize: petSize
                )

                Spacer(minLength: 10)

                AccessRequestReasonForm(
                    selectedReason: $model.selectedReason,
                    customReason: $model.customReasonDraft,
                    isCustomReasonFocused: $isCustomReasonFocused
                )

                Spacer(minLength: 8)

                AccessRequestReminder(remindersAvailable: model.snapshot.remindersAvailable)

                Spacer(minLength: 8)

                AccessRequestFooter(
                    petName: model.presentedPetName,
                    requestAccess: {
                        isCustomReasonFocused = false
                        model.submitAccessRequest()
                    },
                    returnToFocus: {
                        isCustomReasonFocused = false
                        model.cancelAccessRequest()
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .navigationBarBackButtonHidden()
    }
}

private struct AccessRequestHeader: View {
    let species: PetSpecies
    let petName: String
    let goal: String
    let petSize: CGFloat
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 14) {
            PetAvatarView(
                species: species,
                mood: .waiting,
                size: petSize,
                activity: .waiting,
                accessibilityName: petName
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(FocusPresentationCopy.accessRequestHeader(petName: petName, locale: locale))
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(FocusPresentationCopy.accessRequestInstruction(petName: petName, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Label(goal, systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cocoonTextSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 520)
    }
}

private struct AccessRequestReasonForm: View {
    @Binding var selectedReason: AccessReasonKind
    @Binding var customReason: String
    let isCustomReasonFocused: FocusState<Bool>.Binding

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What do you need to take care of?", systemImage: "text.bubble")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AccessReasonKind.allCases.filter { $0 != .custom }) { reason in
                    AccessReasonChip(
                        reason: reason,
                        isSelected: selectedReason == reason && customReason.isEmpty,
                        select: {
                            customReason = ""
                            selectedReason = reason
                            isCustomReasonFocused.wrappedValue = false
                        }
                    )
                }
            }

            TextField("Or write your own reason", text: $customReason)
                .focused(isCustomReasonFocused)
                .submitLabel(.done)
                .onSubmit { isCustomReasonFocused.wrappedValue = false }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.cocoonSurfaceSoft)
                .clipShape(.rect(cornerRadius: 15))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.cocoonStone.opacity(0.5), lineWidth: 1)
                }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 2)
        .frame(maxWidth: 520)
        .background(Color.cocoonPaper.opacity(0.54))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.cocoonStone.opacity(0.48))
                .frame(height: 1)
        }
    }
}

private struct AccessRequestReminder: View {
    let remindersAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Step away temporarily", systemImage: "lock.open")
                .font(.subheadline.weight(.semibold))

            Text("After you confirm, Focumi will request temporary access to your selected apps. Your goal and return path stay here. We'll remind you after 10 and 30 minutes, then close this focus session after 60 minutes.")
                .font(.caption)
                .foregroundStyle(Color.cocoonTextSecondary)
                .lineLimit(4)
                .minimumScaleFactor(0.78)

            if !remindersAvailable {
                Label(
                    "Reminders are unavailable. Return to this app yourself when you're ready.",
                    systemImage: "bell.slash"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cocoonTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: 520, alignment: .leading)
    }
}

private struct AccessRequestFooter: View {
    let petName: String
    let requestAccess: () -> Void
    let returnToFocus: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button("Keep my place", action: requestAccess)
                .buttonStyle(CocoonPrimaryButtonStyle())

            Button("Continue with \(petName)", action: returnToFocus)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cocoonTextSecondary)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: 520)
    }
}

private struct AccessReasonChip: View {
    let reason: AccessReasonKind
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(reason.label)
                    .lineLimit(2)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.cocoonTextPrimary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? Color.cocoonAccent : Color.cocoonSurfaceSoft)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.cocoonAccent : Color.cocoonStone.opacity(0.5),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AccessWindowMVPView: View {
    let model: FriendMVPModel

    @State private var endConfirmation = FocusEndConfirmationState(
        isPresented: ProcessInfo.processInfo.arguments.contains(
            "--friend-mvp-preview-end-confirmation"
        )
    )

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remainingAccessTime(at: context.date)

            ZStack {
                CinematicFocusBeam(treatment: .returning)

                ScrollView {
                    VStack(spacing: 16) {
                        ReturnTogetherCinematicHero(
                            species: model.snapshot.pet ?? .cat,
                            petName: model.presentedPetName,
                            goal: model.snapshot.goal,
                            remaining: remaining
                        )

                        ReturnTogetherNotice(petName: model.presentedPetName)
                            .accessibilitySortPriority(2)

                        AccessWindowFooter(
                            petName: model.presentedPetName,
                            returnToFocus: model.returnToFocus,
                            endForNow: { endConfirmation.request() }
                        )
                        .accessibilitySortPriority(1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaPadding(.top, 28)
                .safeAreaPadding(.bottom, 18)

                if endConfirmation.isPresented {
                    FocusEndConfirmationOverlay(
                        species: model.snapshot.pet ?? .cat,
                        petName: model.presentedPetName,
                        continueFocusing: { endConfirmation.continueFocusing() },
                        confirmEnd: {
                            guard endConfirmation.confirmEnd() else { return }
                            model.endSession()
                        }
                    )
                }
            }
            .onChange(of: context.date) {
                model.reconcile(at: context.date)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct ReturnTogetherCinematicHero: View {
    let species: PetSpecies
    let petName: String
    let goal: String
    let remaining: TimeInterval

    var body: some View {
        VStack(spacing: 7) {
            // Keep the goal and time above the large original character asset:
            // neither may be obscured by a pet at a 390-point phone width.
            CinematicGoalBeam(
                goal: goal,
                timeLabel: String(localized: "Temporary access time"),
                timeValue: timeString(remaining),
                style: .compact
            )
            .frame(maxWidth: 390)

            ReturnSignatureStage(
                species: species,
                petName: petName
            )
            .accessibilityHidden(true)
        }
        .frame(maxWidth: 500)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(4)
    }
}

/// The production Return performance plays while the user is on the truthful
/// access-window surface. It is visual companionship only; the adjacent copy
/// continues to say that iPhone is being asked to limit the selected apps.
private struct ReturnSignatureStage: View {
    let species: PetSpecies
    let petName: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                FocumiCompanionIcon(kind: .pageTurn, tint: species.editorialAccent, size: 16)
                Text("Returning to this page")
                    .font(.caption.bold().smallCaps())
                    .fontDesign(.serif)
                    .foregroundStyle(Color.cocoonTextSecondary)
            }
            .accessibilityHidden(true)

            ReturnSignaturePetView(species: species, size: 320)
        }
        .frame(maxWidth: .infinity)
        .background {
            Ellipse()
                .fill(species.editorialAccent.opacity(0.14))
                .frame(width: 326, height: 220)
                .offset(y: 42)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(species.editorialAccent.opacity(0.48))
                .frame(width: 218, height: 1)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("\(petName) is returning attention to the page")
    }
}

private struct ReturnTogetherNotice: View {
    let petName: String
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            FocumiCompanionIcon(kind: .pageTurn, tint: .cocoonAccentSoft, size: 19)
            Text(FocusPresentationCopy.returnNotice(petName: petName, locale: locale))
        }
        .font(.caption)
        .foregroundStyle(Color.cocoonTextSecondary)
        .lineLimit(2)
        .minimumScaleFactor(0.78)
        .frame(maxWidth: 520, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct AccessWindowFooter: View {
    let petName: String
    let returnToFocus: () -> Void
    let endForNow: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button("Continue with \(petName)", action: returnToFocus)
                .buttonStyle(CocoonPrimaryButtonStyle())

            Button("Pause for now", action: endForNow)
                .buttonStyle(CocoonSecondaryButtonStyle())
        }
        .frame(maxWidth: 520)
    }
}

private struct CompletionMVPView: View {
    let model: FriendMVPModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            CompletionBackdrop()

            ScrollView {
                VStack(spacing: 0) {
                    Text("一起完成了")
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.cocoonTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilitySortPriority(6)

                    PetAvatarView(
                        species: model.snapshot.pet ?? .cat,
                        mood: .celebrating,
                        size: companionSize,
                        activity: .forPhase(.completed),
                        accessibilityName: model.presentedPetName,
                        repeatsAnimation: false
                    )
                    .padding(.top, companionTopPadding)
                    .padding(.bottom, companionBottomPadding)
                    .accessibilitySortPriority(5)

                    Text(model.snapshot.goal)
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.cocoonTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("已完成目标：\(model.snapshot.goal)")
                        .accessibilitySortPriority(4)

                    Text(focusDurationText)
                        .font(.title3.weight(.medium))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(Color.cocoonTextSecondary)
                        .padding(.top, 10)
                        .accessibilityLabel("本次专注时长：\(focusDurationText)")
                        .accessibilitySortPriority(3)

                    VStack(spacing: actionSpacing) {
                        Button("Focus again") {
                            // Both completion actions retain their existing reducer route:
                            // returning to setup so the next focus can be planned.
                            model.dismissCompletion()
                        }
                        .buttonStyle(CompletionPrimaryButtonStyle())
                        .accessibilitySortPriority(2)

                        Button("Finish for now") {
                            model.dismissCompletion()
                        }
                        .buttonStyle(.plain)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.cocoonTextSecondary)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                        .accessibilitySortPriority(1)
                    }
                    .frame(maxWidth: 520)
                    .padding(.top, actionTopPadding)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, contentTopPadding)
                .padding(.bottom, contentBottomPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 12)
            .safeAreaPadding(.bottom, usesAccessibilityLayout ? 0 : 12)
        }
        .navigationBarBackButtonHidden()
        .sensoryFeedback(.success, trigger: model.snapshot.completedSessions)
    }

    private var focusDurationText: String {
        let minutes = max(1, Int(model.snapshot.plannedFocusDuration / 60))
        return FocusPresentationCopy.durationLabel(minutes: minutes, locale: locale)
    }

    // At accessibility text sizes, text keeps its full Dynamic Type scale while
    // only decorative whitespace and the companion frame compact enough for both
    // completion actions to remain reachable in the initial viewport.
    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var companionSize: CGFloat { usesAccessibilityLayout ? 190 : 320 }
    private var companionTopPadding: CGFloat { usesAccessibilityLayout ? 12 : 24 }
    private var companionBottomPadding: CGFloat { usesAccessibilityLayout ? 14 : 28 }
    private var actionSpacing: CGFloat { usesAccessibilityLayout ? 8 : 12 }
    private var actionTopPadding: CGFloat { usesAccessibilityLayout ? 22 : 44 }
    private var horizontalPadding: CGFloat { usesAccessibilityLayout ? 22 : 28 }
    private var contentTopPadding: CGFloat { usesAccessibilityLayout ? 20 : 42 }
    private var contentBottomPadding: CGFloat { usesAccessibilityLayout ? 16 : 28 }
}

/// Completion stays intentionally quiet: the approved companion art carries the
/// story while a plain warm surface keeps the completed goal and next action clear.
private struct CompletionBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.cocoonBackground
            VintagePaperGrain(tint: colorScheme == .dark ? .cocoonAccentSoft : .cocoonButter)
                .opacity(colorScheme == .dark ? 0.08 : 0.055)
                .padding(.horizontal, 34)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct CompletionPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(colorScheme == .dark ? Color.cocoonTextPrimary : Color.cocoonPaper)
            .background(Color.cocoonAccentSoft.opacity(configuration.isPressed ? 0.86 : 1))
            .clipShape(.rect(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A single, non-card companion stage. The page holds functional information;
/// this soft paper wash gives each approved static pose a shared world without
/// turning it into a poster tile. It carries no system state and is decorative
/// to VoiceOver because the surrounding page exposes the real focus facts.
private struct VintageCompanionStage: View {
    let species: PetSpecies
    let size: CGFloat
    let activity: PetActivityScene
    let petName: String
    let caption: LocalizedStringKey

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                FocumiCompanionIcon(kind: .bookmarkPaw, tint: species.editorialAccent, size: 16)
                Text(caption)
                    .font(.caption.bold().smallCaps())
                    .fontDesign(.serif)
                    .foregroundStyle(Color.cocoonTextSecondary)
            }
            .accessibilityHidden(true)

            PetAvatarView(
                species: species,
                mood: activity == .waiting ? .waiting : (activity == .playBall ? .celebrating : .focusing),
                size: size,
                activity: activity,
                accessibilityName: petName,
                repeatsAnimation: false
            )
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            CompanionReadableStageSurface(species: species, size: size)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(species.editorialAccent.opacity(0.48))
                .frame(width: min(240, size * 0.68), height: 1)
                .accessibilityHidden(true)
        }
        // Keep approved art and its book in a separate compositing pass from
        // the dark world light. This is visual-only and carries no status.
        .compositingGroup()
    }
}

/// A stable, noninteractive paper stage behind the companion. In dark
/// appearance it supplies a warm neutral separation surface so black, orange,
/// white, and sage/blue details remain readable without tinting the artwork.
private struct CompanionReadableStageSurface: View {
    let species: PetSpecies
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let isDark = colorScheme == .dark
        let fillOpacity = isDark ? (contrast == .increased ? 1.0 : 0.96) : 0.14
        let outlineOpacity = isDark ? (contrast == .increased ? 0.80 : 0.60) : 0.34

        Ellipse()
            .fill(isDark ? Color.cocoonPetStage.opacity(fillOpacity) : species.editorialAccent.opacity(fillOpacity))
            .frame(width: size * 1.08, height: size * 0.72)
            .offset(y: size * 0.14)
            .overlay {
                Ellipse()
                    .strokeBorder(species.editorialAccent.opacity(outlineOpacity), lineWidth: isDark ? 1.5 : 1)
                    .frame(width: size * 1.08, height: size * 0.72)
                    .offset(y: size * 0.14)
            }
            .shadow(color: isDark ? Color.black.opacity(0.20) : Color.cocoonTextPrimary.opacity(0.08), radius: isDark ? 10 : 4, y: 5)
            .accessibilityHidden(true)
            .compositingGroup()
    }
}

private struct BetaCommercialFeedbackView: View {
    let submit: (
        BetaValidationProductUnderstanding,
        BetaValidationOwnershipDesire,
        BetaValidationPurchaseDriver,
        BetaValidationPurchaseIntent,
        BetaValidationPriceBucket?,
        BetaValidationPriceBucket?
    ) -> Void
    let skip: () -> Void

    @State private var understanding: BetaValidationProductUnderstanding = .companionAndBlocking
    @State private var desire: BetaValidationOwnershipDesire = .interested
    @State private var driver: BetaValidationPurchaseDriver = .companion
    @State private var intent: BetaValidationPurchaseIntent = .mightBuy
    @State private var price: BetaValidationPriceBucket = .usd299
    @State private var usesCustomPrice = false
    @State private var customPriceText = ""

    private var customPriceBucket: BetaValidationPriceBucket? {
        guard usesCustomPrice,
              let value = Decimal(
                string: customPriceText.replacingOccurrences(of: ",", with: "."),
                locale: Locale(identifier: "en_US_POSIX")
              ) else {
            return nil
        }
        return BetaValidationPriceBucket.customBucket(forUSD: value)
    }

    private var canSubmit: Bool {
        !usesCustomPrice || customPriceBucket != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This short beta check helps us decide whether the concept is worth a real paid test. It is not a purchase, and an answer does not prove payment.")
                        .font(.footnote)
                        .foregroundStyle(Color.cocoonTextSecondary)
                }

                Section("What does this product feel like?") {
                    Picker("Product idea", selection: $understanding) {
                        ForEach(BetaValidationProductUnderstanding.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("Would you want to keep it?", selection: $desire) {
                        ForEach(BetaValidationOwnershipDesire.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("Most valuable part", selection: $driver) {
                        ForEach(BetaValidationPurchaseDriver.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("One-time purchase signal") {
                    Text("If this free TestFlight beta ended and the finished app cost about USD $2.99 once, would you really consider buying it?")
                        .font(.subheadline)

                    Picker("Purchase intent", selection: $intent) {
                        ForEach(BetaValidationPurchaseIntent.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("Price that feels reasonable", selection: $price) {
                        ForEach(BetaValidationPriceBucket.surveyOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Toggle("Enter another amount", isOn: $usesCustomPrice)

                    if usesCustomPrice {
                        TextField("USD amount", text: $customPriceText)
                            .keyboardType(.decimalPad)
                            .textContentType(.none)

                        Text("Only a de-identified price range is saved, not the exact amount.")
                            .font(.footnote)
                            .foregroundStyle(Color.cocoonTextSecondary)
                    }
                }

                Section {
                    Button("Save beta answer") {
                        submit(
                            understanding,
                            desire,
                            driver,
                            intent,
                            usesCustomPrice ? nil : price,
                            customPriceBucket
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!canSubmit)
                } footer: {
                    Text("Your answer stays on this iPhone unless you choose to share the de-identified beta report. Real commercial validation still requires an actual App Store purchase.")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listSectionSpacing(20)
            .background(Color.clear)
            .navigationTitle("One quick question")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: intent) {
                if intent == .freeOnly || intent == .wouldNotBuy {
                    price = .free
                    usesCustomPrice = false
                    customPriceText = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: skip)
                }
            }
        }
    }
}

private struct FriendSettingsView: View {
    let model: FriendMVPModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @AppStorage(FocumiInterfaceLanguage.storageKey)
    private var interfaceLanguageRawValue = FocumiInterfaceLanguage.system.rawValue
    @State private var showsPetChange = false

    var body: some View {
        NavigationStack {
            ZStack {
            (colorScheme == .dark ? Color(uiColor: .systemGroupedBackground) : Color.cocoonBackground)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    FocumiSettingsGroup(title: copy("Companion")) {
                        LabeledContent(copy("Current companion"), value: CompanionPresentation.displayName(for: model.snapshot.pet, storedName: model.snapshot.petName))

                        if model.snapshot.phase == .setup {
                            Button(copy("Change companion")) {
                                showsPetChange = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityLabel(copy("Change companion"))
                        }
                    }

                    FocumiSettingsGroup(title: copy("Language")) {
                        Picker(copy("Language"), selection: $interfaceLanguageRawValue) {
                            ForEach(FocumiInterfaceLanguage.allCases, id: \.self) { language in
                                Text(language.settingsLabel(locale: locale)).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("focumi.settings.language")
                    }

                    FocumiSettingsGroup(title: copy("Focus music")) {
                        Toggle(copy("Play gentle focus music"), isOn: musicEnabledBinding)
                            .tint(Color.cocoonAccent)

                        if model.preferences.musicEnabled {
                            Picker(copy("Music"), selection: musicTrackBinding) {
                                ForEach(FocusMusicTrack.allCases) { track in
                                    Text(FocumiSettingsCopy.musicTrackName(track, locale: locale)).tag(track)
                                }
                            }
                            .pickerStyle(.menu)

                            Slider(value: musicVolumeBinding, in: 0...1) {
                                Text(copy("Music volume"))
                            } minimumValueLabel: {
                                Image(systemName: "speaker.fill")
                            } maximumValueLabel: {
                                Image(systemName: "speaker.wave.3.fill")
                            }
                            .tint(Color.cocoonAccent)
                        }
                    }

                    FocumiSettingsGroup(title: copy("Permissions & status")) {
                        LabeledContent(copy("Screen Time")) {
                            Text(copy(model.capability.authorizationState.displayName))
                        }
                        LabeledContent(copy("Notifications")) {
                            Text(copy(model.notificationPermission.displayName))
                        }
                        LabeledContent(copy("Live Activities")) {
                            Text(copy(model.liveActivitiesEnabled ? "Enabled" : "Disabled"))
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(copy("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy("Close")) { dismiss() }
                        .accessibilityIdentifier("focumi.settings.close")
                }
            }
            .sheet(isPresented: $showsPetChange) {
                ChangePetView(model: model)
            }
            .task {
                await model.refreshNotificationPermission()
            }
            }
        }
    }

    private func copy(_ resource: String) -> String {
        FocumiSettingsCopy.text(resource, locale: locale)
    }

    private var musicEnabledBinding: Binding<Bool> {
        Binding(get: { model.preferences.musicEnabled }, set: { value in model.setMusicEnabled(value) })
    }

    private var musicTrackBinding: Binding<FocusMusicTrack> {
        Binding(
            get: { model.preferences.selectedMusicTrack },
            set: { value in model.setMusicTrack(value) }
        )
    }

    private var musicVolumeBinding: Binding<Double> {
        Binding(get: { model.preferences.musicVolume }, set: { value in model.setMusicVolume(value) })
    }

}

private struct FocumiSettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.cocoonTextSecondary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                colorScheme == .dark
                    ? Color(uiColor: .secondarySystemGroupedBackground)
                    : Color.cocoonSurface
            )
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color(uiColor: .separator) : Color.cocoonStone.opacity(0.34),
                        lineWidth: 1
                    )
            }
        }
    }
}

private extension BetaValidationProductUnderstanding {
    var displayName: LocalizedStringResource {
        switch self {
        case .companionAndBlocking: "A focus companion with app blocking"
        case .companionOnly: "Mostly a virtual companion"
        case .blockerOnly: "Mostly an app blocker"
        case .unclear: "The idea is not clear yet"
        }
    }
}

private extension BetaValidationOwnershipDesire {
    var displayName: LocalizedStringResource {
        switch self {
        case .wantToKeep: "I want to keep it"
        case .interested: "I am interested"
        case .neutral: "I am neutral"
        case .notForMe: "It is not for me"
        }
    }
}

private extension BetaValidationPurchaseDriver {
    var displayName: LocalizedStringResource {
        switch self {
        case .companion: "The companion"
        case .appBlocking: "App blocking"
        case .visualPolish: "The visual experience"
        case .liveActivity: "Live Activity and Dynamic Island"
        case .none: "None of these"
        }
    }
}

private extension BetaValidationPurchaseIntent {
    var displayName: LocalizedStringResource {
        switch self {
        case .wouldBuy: "Yes, I would buy it"
        case .mightBuy: "I would seriously consider it"
        case .unsure: "I am unsure"
        case .freeOnly: "I would only use it free"
        case .wouldNotBuy: "No, I would not buy it"
        }
    }
}

private extension BetaValidationPriceBucket {
    static let surveyOptions: [Self] = [.free, .usd099, .usd199, .usd299, .usd499, .usd999]

    var displayName: LocalizedStringResource {
        switch self {
        case .free: "Free only"
        case .usd099: "USD $0.99"
        case .usd199: "USD $1.99"
        case .usd299: "USD $2.99"
        case .usd499: "USD $4.99"
        case .usd999: "USD $9.99"
        case .customUnder099: "Under USD $0.99"
        case .custom100To199: "USD $1.00–$1.99"
        case .custom200To299: "USD $2.00–$2.99"
        case .custom300To499: "USD $3.00–$4.99"
        case .custom500To999: "USD $5.00–$9.99"
        case .custom1000OrMore: "USD $10 or more"
        }
    }
}

private extension P0AuthorizationState {
    var displayName: String {
        switch self {
        case .notDetermined: "Not requested"
        case .denied: "Permission needed"
        case .approved: "Enabled"
        }
    }
}

private extension NotificationPermissionState {
    var displayName: String {
        switch self {
        case .notDetermined: "Not requested"
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        }
    }
}

private struct ChangePetView: View {
    let model: FriendMVPModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showsConfirmation = false

    private var newSpecies: PetSpecies {
        model.snapshot.pet == .cat ? .dog : .cat
    }

    var body: some View {
        NavigationStack {
            ZStack {
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                PetAvatarView(
                    species: newSpecies,
                    mood: .welcome,
                    size: 220,
                    accessibilityName: effectiveName
                )

                VStack(spacing: 8) {
                    Text("Meet \(CompanionPresentation.displayName(for: newSpecies))")
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)

                    Text("Your time with \(CompanionPresentation.displayName(for: model.snapshot.pet, storedName: model.snapshot.petName)) will remain in Shared Memories. Your new friendship begins from its first hello.")
                        .foregroundStyle(Color.cocoonTextSecondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Name (optional)", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(Color.cocoonSurfaceSoft)
                    .clipShape(.rect(cornerRadius: 16))

                Spacer(minLength: 8)

                Button("Continue with this companion") {
                    showsConfirmation = true
                }
                .buttonStyle(CocoonPrimaryButtonStyle())
            }
            .padding(24)
            .background(Color.cocoonBackground.ignoresSafeArea())
            .navigationTitle("Change companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            if showsConfirmation {
                VintageDecisionOverlay(
                    species: newSpecies,
                    title: "Begin a new companionship?",
                    message: "Switching companions does not remove your shared history.",
                    primaryTitle: "Welcome \(effectiveName)",
                    cancelTitle: "Keep \(CompanionPresentation.displayName(for: model.snapshot.pet, storedName: model.snapshot.petName))",
                    confirm: { if model.changePet(to: newSpecies, name: name) { dismiss() } },
                    cancel: { showsConfirmation = false }
                )
            }
            }
        }
    }

    private var effectiveName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CompanionPresentation.displayName(for: newSpecies) : trimmed
    }
}

private struct ArchivedPetMemoryView: View {
    let memory: ArchivedPetMemory
    @Environment(\.locale) private var locale

    private var presentedName: String {
        CompanionPresentation.displayName(for: memory.species, storedName: memory.name)
    }

    var body: some View {
        VStack(spacing: 24) {
            PetAvatarView(
                species: memory.species,
                mood: .welcome,
                size: 220,
                accessibilityName: presentedName
            )

            Text("Your time with \(presentedName)")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)

            VStack(spacing: 14) {
                LabeledContent("Focus sessions", value: "\(memory.completedSessions)")
                LabeledContent("Time together", value: focusedDurationText)
                LabeledContent("Bond", value: "\(memory.bondPoints)")
            }
            .padding(20)
            .background(Color.cocoonSurface, in: .rect(cornerRadius: 20))

            Text("Every session you completed together remains part of your story.")
                .foregroundStyle(Color.cocoonTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .background(Color.cocoonBackground.ignoresSafeArea())
        .navigationTitle("Shared memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var focusedDurationText: String {
        let minutes = Int(memory.focusedDuration / 60)
        if minutes >= 60 {
            return String(
                localized: "\(minutes / 60) hr \(minutes % 60) min",
                locale: locale
            )
        }
        return FocusPresentationCopy.durationLabel(minutes: minutes, locale: locale)
    }
}

private struct CocoonCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cocoonSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .clipShape(.rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.cocoonAccentSoft.opacity(0.72), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
            }
            .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
    }
}

private struct VintageEditorialKicker: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(title)
                .font(.caption2.bold().smallCaps())
                .fontDesign(.serif)
                .tracking(0.8)
        }
        .foregroundStyle(Color.cocoonTextPrimary.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cocoonButter.opacity(0.5), in: Capsule())
        .overlay { Capsule().strokeBorder(Color.cocoonStone.opacity(0.56), style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
        .accessibilityHidden(true)
    }
}

private struct VintageStitchedNote<Content: View>: View {
    let symbol: String
    let tint: Color
    let content: Content

    init(symbol: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)
            content
        }
        .padding(14)
        .background(Color.cocoonPaper.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2.5, 3.5]))
        }
    }
}

private struct VintageSettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let tint: Color
    let content: Content

    init(title: LocalizedStringKey, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VintagePaperCard(tint: tint, tab: title) {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .tint(Color.cocoonAccent)
            .foregroundStyle(Color.cocoonTextPrimary)
        }
    }
}

private struct CocoonPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(Color.cocoonAccent)
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: Color.cocoonAccent.opacity(0.24), radius: 10, y: 5)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CocoonSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Color.cocoonTextPrimary)
            .background(Color.cocoonSurface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.cocoonStone.opacity(0.64), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CocoonDangerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Color.cocoonApricot)
            .background(Color.cocoonSurface.opacity(configuration.isPressed ? 0.7 : 0.96))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.cocoonApricot.opacity(0.72), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension Color {
    /// Semantic, trait-aware paper colours.  The same editorial materials remain warm in
    /// dark appearance, but no light paper or brown body copy is reused as a dark surface.
    private nonisolated static func cocoonAdaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let cocoonBackground = cocoonAdaptive(
        light: UIColor(red: 244 / 255, green: 228 / 255, blue: 191 / 255, alpha: 1),
        dark: UIColor(red: 33 / 255, green: 24 / 255, blue: 19 / 255, alpha: 1)
    )
    static let cocoonPaper = cocoonAdaptive(
        light: UIColor(red: 254 / 255, green: 244 / 255, blue: 217 / 255, alpha: 1),
        dark: UIColor(red: 53 / 255, green: 39 / 255, blue: 31 / 255, alpha: 1)
    )
    static let cocoonSurface = Color.cocoonPaper
    static let cocoonSurfaceSoft = cocoonAdaptive(
        light: UIColor(red: 226 / 255, green: 186 / 255, blue: 103 / 255, alpha: 0.18),
        dark: UIColor(red: 96 / 255, green: 70 / 255, blue: 49 / 255, alpha: 0.72)
    )
    /// A warm, opaque stage material used only behind the approved companion
    /// artwork in dark appearance. It is intentionally separate from the
    /// background beams so the art itself never receives a blend or tint.
    static let cocoonPetStage = cocoonAdaptive(
        light: UIColor(red: 249 / 255, green: 237 / 255, blue: 207 / 255, alpha: 1),
        dark: UIColor(red: 112 / 255, green: 86 / 255, blue: 68 / 255, alpha: 1)
    )
    static let cocoonTextPrimary = cocoonAdaptive(
        light: UIColor(red: 90 / 255, green: 60 / 255, blue: 49 / 255, alpha: 1),
        dark: UIColor(red: 247 / 255, green: 233 / 255, blue: 204 / 255, alpha: 1)
    )
    static let cocoonTextSecondary = cocoonAdaptive(
        light: UIColor(red: 90 / 255, green: 60 / 255, blue: 49 / 255, alpha: 0.74),
        dark: UIColor(red: 216 / 255, green: 196 / 255, blue: 164 / 255, alpha: 0.88)
    )
    static let cocoonAccent = cocoonAdaptive(
        light: UIColor(red: 201 / 255, green: 111 / 255, blue: 93 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 148 / 255, blue: 127 / 255, alpha: 1)
    )
    static let cocoonAccentSoft = cocoonAdaptive(
        light: UIColor(red: 120 / 255, green: 148 / 255, blue: 163 / 255, alpha: 1),
        dark: UIColor(red: 165 / 255, green: 193 / 255, blue: 208 / 255, alpha: 1)
    )
    static let cocoonApricot = cocoonAdaptive(
        light: UIColor(red: 217 / 255, green: 141 / 255, blue: 134 / 255, alpha: 1),
        dark: UIColor(red: 230 / 255, green: 161 / 255, blue: 150 / 255, alpha: 1)
    )
    static let cocoonSage = cocoonAdaptive(
        light: UIColor(red: 132 / 255, green: 149 / 255, blue: 110 / 255, alpha: 1),
        dark: UIColor(red: 181 / 255, green: 195 / 255, blue: 156 / 255, alpha: 1)
    )
    /// v0.6 formal-flow CTA only; dangerous actions retain apricot styling.
    static let cocoonForest = cocoonAdaptive(
        light: UIColor(red: 43 / 255, green: 84 / 255, blue: 61 / 255, alpha: 1),
        dark: UIColor(red: 93 / 255, green: 142 / 255, blue: 108 / 255, alpha: 1)
    )
    static let cocoonStone = cocoonAdaptive(
        light: UIColor(red: 182 / 255, green: 138 / 255, blue: 60 / 255, alpha: 1),
        dark: UIColor(red: 214 / 255, green: 180 / 255, blue: 107 / 255, alpha: 1)
    )
    static let cocoonButter = cocoonAdaptive(
        light: UIColor(red: 226 / 255, green: 186 / 255, blue: 103 / 255, alpha: 1),
        dark: UIColor(red: 235 / 255, green: 203 / 255, blue: 125 / 255, alpha: 1)
    )
}

private extension PetSpecies {
    var editorialAccent: Color {
        switch self {
        case .cat: .cocoonSage
        case .dog: .cocoonAccentSoft
        }
    }

    var choiceAccessibilityLabel: LocalizedStringResource {
        switch self {
        case .cat: "Choose Milo"
        case .dog: "Choose Max"
        }
    }

    var voiceControlLabels: [LocalizedStringKey] {
        switch self {
        case .cat: ["Choose Milo", "Milo"]
        case .dog: ["Choose Max", "Max"]
        }
    }
}

private extension AccessReasonKind {
    var label: LocalizedStringResource {
        switch self {
        case .verificationCode: "Get a verification code"
        case .importantMessage: "Reply to an important message"
        case .studyResearch: "Look up study material"
        case .urgentMatter: "Handle something urgent"
        case .custom: "Custom reason"
        }
    }
}

private func timeString(_ interval: TimeInterval) -> String {
    let totalSeconds = max(0, Int(interval.rounded(.down)))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - v0.6 approved-flow presentation

/// One quiet canvas for the approved core flow. It owns no business state: the
/// reducer-backed model still supplies every phase, deadline and action.
private struct FocumiFlowCanvas<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.cocoonSurface : Color.cocoonBackground)
                .ignoresSafeArea()
            VintagePaperGrain(tint: .cocoonButter)
                .opacity(reduceTransparency ? 0.025 : 0.055)
                .padding(.horizontal, 34)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            content
        }
    }
}

private struct FocumiFlowPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(Color.white)
            .background(Color.cocoonForest.opacity(configuration.isPressed ? 0.86 : 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The paw is a visual signature for positive Milo actions. It is deliberately
/// hidden from VoiceOver so the button continues to announce only its action.
private struct FocumiPawActionLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "pawprint.fill")
                .imageScale(.medium)
                .accessibilityHidden(true)
        }
        .fixedSize()
    }
}

private struct FocumiDurationPicker: View {
    @Binding var duration: TimeInterval
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let supportedDurations = FriendBetaPreferences.supportedFocusDurations

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose focus duration")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.cocoonTextPrimary)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    durationOptions
                }
            } else {
                HStack(spacing: 8) {
                    durationOptions
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var durationOptions: some View {
        ForEach(supportedDurations, id: \.self) { option in
            let isSelected = duration == option
            Button {
                duration = option
            } label: {
                Text(durationTitle(for: option))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(isSelected ? Color.white : Color.cocoonTextPrimary)
                    .background(isSelected ? Color.cocoonForest : Color.cocoonSurfaceSoft)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(durationTitle(for: option)) focus duration")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func durationTitle(for interval: TimeInterval) -> String {
        FocusPresentationCopy.durationLabel(
            minutes: max(1, Int(interval / 60)),
            locale: locale
        )
    }
}

/// The only runtime consumer of the duration reaction trial assets. The
/// 30-minute and unexpected-duration paths retain the existing approved Idle
/// pose, while the selected companion determines every trial image name.
private struct FocumiDurationReactionPose: View {
    let species: PetSpecies
    let duration: TimeInterval
    let size: CGFloat
    let accessibilityLabel: String

    var body: some View {
        switch CompanionPresentation.durationReactionAsset(for: species, duration: duration) {
        case .approvedDefault:
            MiloStaticPoseView(
                species: species,
                mood: .welcome,
                size: size,
                accessibilityLabel: accessibilityLabel
            )
        case .trial(let assetName):
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

private struct FocumiFocusPactView: View {
    let model: FriendMVPModel
    let returnToMeetMilo: () -> Void
    let settingsAction: () -> Void
    @FocusState private var isGoalFocused: Bool
    @State private var showsFreeFocusConfirmation = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var model = model
        FocumiFlowCanvas {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 16) {
                    HStack(spacing: 6) {
                        Text("Task setup")
                        Image(systemName: "pawprint.fill")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    .font(dynamicTypeSize.isAccessibilitySize ? .title3.weight(.bold) : .title.weight(.bold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.cocoonTextPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .id(FocumiCorePreviewAnchor.top)
                    Text("Tell \(model.presentedPetName) what you want to focus on.")
                        .font(.body)
                        .foregroundStyle(Color.cocoonTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What would you like to finish this time?", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.cocoonTextSecondary)
                        TextField("What would you like to finish?", text: $model.goalDraft)
                            .focused($isGoalFocused).submitLabel(.done)
                            .onSubmit { isGoalFocused = false }
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cocoonSurfaceSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    FocumiDurationPicker(duration: $model.durationDraft)
                    FocumiDurationReactionPose(
                        species: model.snapshot.pet ?? .cat,
                        duration: model.durationDraft,
                        size: dynamicTypeSize.isAccessibilitySize ? 140 : 210,
                        accessibilityLabel: "\(model.presentedPetName)，准备陪你开始专注。"
                    )
                    ScreenTimeSetupPanel(model: model, isEditorial: true)
                    Button {
                        isGoalFocused = false
                        if model.needsFreeFocusConfirmation { showsFreeFocusConfirmation = true }
                        else { Task { await model.startSession() } }
                    } label: {
                        FocumiPawActionLabel("Start focus")
                    }
                    .buttonStyle(FocumiFlowPrimaryButtonStyle())
                    .accessibilityLabel("Start focus")
                    .disabled(!(model.canStart || FocusSetupPreview.isReady))
                    .opacity((model.canStart || FocusSetupPreview.isReady) ? 1 : 0.48)
                    .id(FocumiCorePreviewAnchor.bottom)
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 64 : 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                }
                .task { await FocumiCorePreviewAnchor.scrollIfRequested(using: proxy) }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                FocumiTopControlRow(
                    showsBack: true,
                    backAction: returnToMeetMilo,
                    settingsAction: settingsAction
                )
            }
        }
        .navigationBarBackButtonHidden()
        .onChange(of: model.durationDraft) { model.setPreferredDuration(model.durationDraft) }
        .overlay {
            if showsFreeFocusConfirmation {
                VintageDecisionOverlay(
                    species: model.snapshot.pet ?? .cat, title: "Start without a goal?",
                    message: "That is okay. You can start focusing directly with \(model.presentedPetName) this time.",
                    primaryTitle: "Start focus", cancelTitle: "Add a goal",
                    showsEditorialKicker: false,
                    confirm: { Task { await model.startSession(allowFreeFocus: true) } },
                    cancel: { isGoalFocused = true; showsFreeFocusConfirmation = false }
                )
            }
        }
    }
}

private enum FocumiCorePreviewAnchor: String, Hashable {
    case top
    case bottom

    static func scrollIfRequested(using proxy: ScrollViewProxy) async {
#if DEBUG
        guard let rawValue = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--friend-mvp-v06-scroll=") })?
            .split(separator: "=", maxSplits: 1)
            .last,
              let anchor = Self(rawValue: String(rawValue))
        else { return }

        // Screenshot-only fixture. It is compiled out of Release and does not
        // alter the model, selection, timer, or persisted route.
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.none) { proxy.scrollTo(anchor, anchor: anchor == .bottom ? .bottom : .top) }
#endif
    }
}

private struct FocumiFocusPageView: View {
    let model: FriendMVPModel
    @State private var endConfirmation = FocusEndConfirmationState()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            FocumiFlowCanvas {
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 20) {
                        Text(model.snapshot.goal).font(.title2.weight(.bold)).fontDesign(.serif)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    MiloStaticPoseView(
                        species: model.snapshot.pet ?? .cat,
                        mood: .focusing,
                            size: dynamicTypeSize.isAccessibilitySize ? 230 : 330,
                        accessibilityLabel: "\(model.presentedPetName)，正在陪你专注。"
                        )
                        Text("Focusing together").font(.subheadline.weight(.semibold)).foregroundStyle(Color.cocoonTextSecondary)
                        Text(timeString(model.remainingFocusTime(at: context.date)))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                            .contentTransition(.numericText())
                        if model.capability.needsFocusProtectionWarning { FocusProtectionWarning() }
                        Button("End now") { endConfirmation.request() }
                            .font(.body.weight(.semibold)).foregroundStyle(Color.cocoonAccent).frame(minHeight: 44)
                    }
                    .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                    .padding(.vertical, 28).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                if endConfirmation.isPresented {
                    FocusEndConfirmationOverlay(
                        species: model.snapshot.pet ?? .cat, petName: model.presentedPetName,
                        continueFocusing: { endConfirmation.continueFocusing() },
                        confirmEnd: { guard endConfirmation.confirmEnd() else { return }; model.endSession() }
                    )
                }
            }
            .onChange(of: context.date) { model.reconcile(at: context.date) }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct FocumiAccessRequestPageView: View {
    let model: FriendMVPModel
    @FocusState private var isCustomReasonFocused: Bool

    var body: some View {
        @Bindable var model = model
        FocumiFlowCanvas {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Step away temporarily").font(.title2.weight(.bold)).fontDesign(.serif).multilineTextAlignment(.center)
                    MiloStaticPoseView(
                        species: model.snapshot.pet ?? .cat,
                        mood: .waiting,
                        size: 230,
                        accessibilityLabel: "\(model.presentedPetName)，正在等你确认临时离开。"
                    )
                    Text(model.snapshot.goal).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    AccessRequestReasonForm(selectedReason: $model.selectedReason, customReason: $model.customReasonDraft, isCustomReasonFocused: $isCustomReasonFocused)
                    AccessRequestReminder(remindersAvailable: model.snapshot.remindersAvailable)
                    Button("Keep my place") { isCustomReasonFocused = false; model.submitAccessRequest() }.buttonStyle(FocumiFlowPrimaryButtonStyle())
                    Button("Continue with \(model.presentedPetName)") { isCustomReasonFocused = false; model.cancelAccessRequest() }
                        .font(.body.weight(.semibold)).foregroundStyle(Color.cocoonTextSecondary).frame(minHeight: 44)
                }
                .padding(.horizontal, 24).padding(.vertical, 28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden()
    }
}

private struct FocumiWaitingPageView: View {
    let model: FriendMVPModel
    @State private var endConfirmation = FocusEndConfirmationState()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            FocumiFlowCanvas {
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 20) {
                        Text("\(model.presentedPetName) is waiting here").font(.title2.weight(.bold)).fontDesign(.serif).multilineTextAlignment(.center)
                        MiloStaticPoseView(
                            species: model.snapshot.pet ?? .cat,
                            mood: .waiting,
                            size: dynamicTypeSize.isAccessibilitySize ? 230 : 320,
                            accessibilityLabel: "\(model.presentedPetName)，正在等你回来继续专注。"
                        )
                        Text(model.snapshot.goal).font(.title3.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Text("Temporary access remaining \(timeString(model.remainingAccessTime(at: context.date)))")
                            .font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(Color.cocoonTextSecondary)
                        Text(FocusPresentationCopy.returnNotice(petName: model.presentedPetName, locale: locale))
                            .font(.caption).foregroundStyle(Color.cocoonTextSecondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Button { model.returnToFocus() } label: {
                            FocumiPawActionLabel("Focus together again")
                        }
                        .buttonStyle(FocumiFlowPrimaryButtonStyle())
                        .accessibilityLabel("Focus together again")
                        Button("Finish here") { endConfirmation.request() }.font(.body.weight(.semibold)).foregroundStyle(Color.cocoonTextSecondary).frame(minHeight: 44)
                    }
                    .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                    .padding(.vertical, 28).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                if endConfirmation.isPresented {
                    FocusEndConfirmationOverlay(
                        species: model.snapshot.pet ?? .cat, petName: model.presentedPetName,
                        continueFocusing: { endConfirmation.continueFocusing() },
                        confirmEnd: { guard endConfirmation.confirmEnd() else { return }; model.endSession() }
                    )
                }
            }
            .onChange(of: context.date) { model.reconcile(at: context.date) }
        }
        .navigationBarBackButtonHidden()
    }
}

/// Presentation-only return acknowledgement. The app-owned visual recognizes
/// the return; it does not assert that ManagedSettings or Shield has completed.
private struct FocumiReturnRecognitionView: View {
    let model: FriendMVPModel

    var body: some View {
        FocumiFlowCanvas {
            FocumiReturnRecognitionSurface(
                goal: model.snapshot.goal,
                showAction: true
            )
        }
        .navigationBarBackButtonHidden()
    }
}

private struct FocumiReturnRecognitionSurface: View {
    let goal: String
    let showAction: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text("I see you are back")
                .font(.title.weight(.bold))
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
            MiloStaticPoseView(
                species: .cat,
                mood: .waiting,
                size: 320,
                accessibilityLabel: "Milo，注意到你回来了。"
            )
            Text(goal)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("Return to this page and continue focusing together")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cocoonTextSecondary)
                .multilineTextAlignment(.center)
            if showAction {
                Text("Continue focusing")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.cocoonForest, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: 560, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }
}

private struct FocumiCompletionPageView: View {
    let model: FriendMVPModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        FocumiFlowCanvas {
            ScrollView {
                VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 20) {
                    Text("Finished together").font(.title2.weight(.bold)).fontDesign(.serif).multilineTextAlignment(.center)
                    MiloStaticPoseView(
                        species: model.snapshot.pet ?? .cat,
                        mood: .celebrating,
                        size: dynamicTypeSize.isAccessibilitySize ? 230 : 320,
                        accessibilityLabel: "\(model.presentedPetName)，为你的完成庆祝。"
                    )
                    Text(model.snapshot.goal).font(.title3.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Text(focusDurationText).font(.title3.weight(.medium)).monospacedDigit().foregroundStyle(Color.cocoonTextSecondary)
                    Button { model.dismissCompletion() } label: {
                        FocumiPawActionLabel("Done")
                    }
                    .buttonStyle(FocumiFlowPrimaryButtonStyle())
                    .accessibilityLabel("Done")
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.vertical, 28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden()
        .sensoryFeedback(.success, trigger: model.snapshot.completedSessions)
    }

    private var focusDurationText: String {
        FocusPresentationCopy.durationLabel(
            minutes: max(1, Int(model.snapshot.plannedFocusDuration / 60)),
            locale: locale
        )
    }
}

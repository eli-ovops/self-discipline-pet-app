import Foundation
import Testing
import UIKit
import SwiftUI
@testable import DisciplinedPet

@Suite("Friend MVP reducer")
struct FriendMVPReducerTests {
    @Test("Cocoon palette resolves safely away from the main queue")
    func cocoonPaletteResolvesOffMainQueue() {
        let palette: [Color] = [
            .cocoonBackground,
            .cocoonPaper,
            .cocoonSurfaceSoft,
            .cocoonPetStage,
            .cocoonTextPrimary,
            .cocoonTextSecondary,
            .cocoonAccent,
            .cocoonAccentSoft,
            .cocoonApricot,
            .cocoonSage,
            .cocoonForest,
            .cocoonStone,
            .cocoonButter,
        ]
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        DispatchQueue.global(qos: .userInitiated).sync {
            for color in palette {
                _ = UIColor(color).resolvedColor(with: darkTraits)
            }
        }
    }

    @Test("Adoption uses the pet default name when the custom name is blank")
    func adoptionUsesDefaultName() {
        let now = Date(timeIntervalSince1970: 100)
        let result = FriendMVPReducer.reduce(
            snapshot: .fresh(now: now),
            event: .petAdopted(species: .cat, name: "   ", at: now)
        )

        #expect(result.snapshot.pet == .cat)
        #expect(result.snapshot.petName == "Milo")
        #expect(result.snapshot.phase == .setup)
        #expect(result.effects == [.persist])
    }

    @Test("Approved static companion routing keeps Milo and Max species consistent")
    func approvedStaticCompanionRoutingKeepsSpeciesConsistent() {
        #expect(CompanionPresentation.assetName(for: .cat, mood: .welcome) == "FocumiMiloIdle")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .focusing) == "FocumiMiloFocus")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .waiting) == "FocumiMiloWaiting")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .celebrating) == "FocumiMiloComplete")
        #expect(CompanionPresentation.assetName(for: .dog, mood: .welcome) == "FocumiMaxIdle")
        #expect(CompanionPresentation.assetName(for: .dog, mood: .focusing) == "FocumiMaxFocus")
        #expect(CompanionPresentation.assetName(for: .dog, mood: .waiting) == "FocumiMaxWaiting")
        #expect(CompanionPresentation.assetName(for: .dog, mood: .celebrating) == "FocumiMaxComplete")

        let dog = FriendMVPReducer.reduce(
            snapshot: .fresh(),
            event: .petAdopted(species: .dog, name: "Max", at: Date())
        ).snapshot
        #expect(dog.pet == .dog)
        #expect(dog.petName == "Max")
    }

    @Test("Duration reaction presentation keeps companion and duration routing explicit")
    func durationReactionPresentationRoutesMiloAndMaxWithoutStateChanges() {
        #expect(CompanionPresentation.durationReactionAsset(for: .cat, duration: 30 * 60) == .approvedDefault)
        #expect(CompanionPresentation.durationReactionAsset(for: .cat, duration: 45 * 60) == .trial("FocumiMiloDuration45"))
        #expect(CompanionPresentation.durationReactionAsset(for: .cat, duration: 60 * 60) == .trial("FocumiMiloDuration60"))
        #expect(CompanionPresentation.durationReactionAsset(for: .cat, duration: 120 * 60) == .trial("FocumiMiloDuration120"))

        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 30 * 60) == .approvedDefault)
        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 45 * 60) == .trial("FocumiMaxDuration45"))
        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 60 * 60) == .trial("FocumiMaxDuration60"))
        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 120 * 60) == .trial("FocumiMaxDuration120"))
    }

    @Test("Unexpected duration reaction values retain the approved companion default")
    func durationReactionPresentationFallsBackToApprovedDefault() {
        #expect(CompanionPresentation.durationReactionAsset(for: .cat, duration: 15 * 60) == .approvedDefault)
        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 90 * 60) == .approvedDefault)
        #expect(CompanionPresentation.durationReactionAsset(for: .dog, duration: 60 * 60 + 1) == .approvedDefault)
    }

    @Test("Setup companion confirmation returns to Task Setup for the current Milo")
    func setupCompanionConfirmationReturnsToTaskSetupForCurrentMilo() {
        #expect(CompanionPresentation.setupCompanionConfirmationRoute(
            currentPet: .cat,
            selectedPet: .cat
        ) == .returnToTaskSetup)
    }

    @Test("Setup companion confirmation returns to Task Setup for the current Max")
    func setupCompanionConfirmationReturnsToTaskSetupForCurrentMax() {
        #expect(CompanionPresentation.setupCompanionConfirmationRoute(
            currentPet: .dog,
            selectedPet: .dog
        ) == .returnToTaskSetup)
    }

    @Test("Setup companion callback accepts the already selected Milo and Max")
    @MainActor
    func setupCompanionConfirmationAcceptsCurrentCompanion() throws {
        let miloSuiteName = "FriendMVPSetupCurrentMiloTests.\(UUID().uuidString)"
        let miloDefaults = try #require(UserDefaults(suiteName: miloSuiteName))
        defer { miloDefaults.removePersistentDomain(forName: miloSuiteName) }
        let miloStore = FriendMVPStore(defaults: miloDefaults)
        let miloSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(), event: .petAdopted(species: .cat, name: "", at: Date())
        ).snapshot
        miloStore.save(.init(snapshot: miloSetup, preferences: .fresh()))

        let maxSuiteName = "FriendMVPSetupCurrentMaxTests.\(UUID().uuidString)"
        let maxDefaults = try #require(UserDefaults(suiteName: maxSuiteName))
        defer { maxDefaults.removePersistentDomain(forName: maxSuiteName) }
        let maxStore = FriendMVPStore(defaults: maxDefaults)
        let maxSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(), event: .petAdopted(species: .dog, name: "", at: Date())
        ).snapshot
        maxStore.save(.init(snapshot: maxSetup, preferences: .fresh()))

        let miloModel = FriendMVPModel(store: miloStore)
        let maxModel = FriendMVPModel(store: maxStore)
        #expect(miloModel.confirmSetupCompanionSelection(.cat))
        #expect(maxModel.confirmSetupCompanionSelection(.dog))
        #expect(miloModel.snapshot.phase == .setup)
        #expect(maxModel.snapshot.phase == .setup)
        #expect(miloModel.snapshot.pet == .cat)
        #expect(maxModel.snapshot.pet == .dog)
    }

    @Test("Setup companion confirmation commits a Max-to-Milo selection")
    @MainActor
    func setupCompanionConfirmationCommitsMaxToMilo() throws {
        let suiteName = "FriendMVPSetupCompanionConfirmMiloTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FriendMVPStore(defaults: defaults)
        let maxSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(), event: .petAdopted(species: .dog, name: "", at: Date())
        ).snapshot
        var preferences = FriendBetaPreferences.fresh()
        // Legacy stores can contain zero. It is compatibility data only and
        // must not gate the production Setup confirmation callback.
        preferences.remainingPetChanges = 0
        store.save(.init(snapshot: maxSetup, preferences: preferences))

        let model = FriendMVPModel(store: store)
        #expect(CompanionPresentation.setupCompanionConfirmationRoute(
            currentPet: model.snapshot.pet,
            selectedPet: .cat
        ) == .commitCompanionChange)
        #expect(model.confirmSetupCompanionSelection(.cat))
        #expect(model.snapshot.phase == .setup)
        #expect(model.snapshot.pet == .cat)
        #expect(model.preferences.remainingPetChanges == 0)

        let restored = FriendMVPModel(store: store)
        #expect(restored.snapshot.pet == .cat)
        #expect(restored.preferences.remainingPetChanges == 0)
    }

    @Test("Setup companion confirmation retains the Max confirmation path")
    @MainActor
    func setupCompanionConfirmationRetainsMaxPath() throws {
        let suiteName = "FriendMVPSetupCompanionConfirmMaxTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FriendMVPStore(defaults: defaults)
        let miloSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(), event: .petAdopted(species: .cat, name: "", at: Date())
        ).snapshot
        var preferences = FriendBetaPreferences.fresh()
        preferences.remainingPetChanges = 0
        store.save(.init(snapshot: miloSetup, preferences: preferences))

        let model = FriendMVPModel(store: store)
        #expect(CompanionPresentation.setupCompanionConfirmationRoute(
            currentPet: model.snapshot.pet,
            selectedPet: .dog
        ) == .commitCompanionChange)
        #expect(model.confirmSetupCompanionSelection(.dog))
        #expect(model.snapshot.phase == .setup)
        #expect(model.snapshot.pet == .dog)
        #expect(model.preferences.remainingPetChanges == 0)
    }

    @Test("Setup companion callback supports repeated bidirectional switches with legacy allowance values")
    @MainActor
    func setupCompanionConfirmationAllowsRepeatedBidirectionalSwitches() throws {
        let suiteName = "FriendMVPSetupCompanionRepeatTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FriendMVPStore(defaults: defaults)
        let maxSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(), event: .petAdopted(species: .dog, name: "", at: Date())
        ).snapshot
        var preferences = FriendBetaPreferences.fresh()
        preferences.remainingPetChanges = 0
        store.save(.init(snapshot: maxSetup, preferences: preferences))

        let model = FriendMVPModel(store: store)
        #expect(model.confirmSetupCompanionSelection(.cat))
        #expect(model.confirmSetupCompanionSelection(.dog))
        #expect(model.confirmSetupCompanionSelection(.cat))
        #expect(model.snapshot.pet == .cat)
        #expect(model.preferences.remainingPetChanges == 0)

        let restored = FriendMVPModel(store: store)
        #expect(restored.snapshot.pet == .cat)
        #expect(restored.preferences.remainingPetChanges == 0)
    }

    @Test("An active session keeps its companion even when legacy allowance is positive")
    @MainActor
    func activeSessionDoesNotAllowCompanionChange() throws {
        let suiteName = "FriendMVPSetupCompanionActiveSessionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FriendMVPStore(defaults: defaults)
        var preferences = FriendBetaPreferences.fresh()
        preferences.remainingPetChanges = 1
        store.save(.init(snapshot: focusingSnapshot(start: Date()), preferences: preferences))

        let model = FriendMVPModel(store: store)
        #expect(model.confirmSetupCompanionSelection(.cat) == false)
        #expect(model.snapshot.phase == .focusing)
        #expect(model.snapshot.pet == .dog)
        #expect(model.preferences.remainingPetChanges == 1)
    }

    @Test("v0.6 opening presentation only appears for normal idle")
    func v06OpeningRouteSkipsRestoredWorkAndProblems() {
        func capability(
            phase: P0SessionPhase = .idle,
            authorization: P0AuthorizationState = .approved,
            selectedItemCount: Int = 0,
            error: String? = nil
        ) -> P0CapabilityState {
            .init(
                sessionID: UUID(), generation: 0, phase: phase,
                authorization: authorization, selectedItemCount: selectedItemCount,
                lastConsumedIntentID: nil, lastCommandReceipt: nil,
                latestErrorCode: error
            )
        }

        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .onboarding, dataRecoveryNeeded: false, capabilityState: capability()
        ) == .brandMoment)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .setup, dataRecoveryNeeded: false, capabilityState: capability()
        ) == .brandMoment)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .focusing, dataRecoveryNeeded: false, capabilityState: capability()
        ) == .unfinishedSession)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .setup, dataRecoveryNeeded: true, capabilityState: capability()
        ) == .recovery)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .setup, dataRecoveryNeeded: false,
            capabilityState: capability(authorization: .notDetermined, selectedItemCount: 13)
        ) == .brandMoment)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .setup, dataRecoveryNeeded: false,
            capabilityState: capability(authorization: .denied, selectedItemCount: 13),
            isPermissionPresentationActive: true
        ) == .permission)
        #expect(CompanionPresentation.v06OpeningRoute(
            phase: .setup, dataRecoveryNeeded: false,
            capabilityState: capability(phase: .recoveryRequired, error: "authorization_required")
        ) == .error)
    }

    @Test("The normal opening uses exactly one text-free cat and dog paw mark")
    func doublePawOpeningBrandContract() {
        #expect(CompanionPresentation.DoublePawBranding.marks == [.cat, .dog])
        #expect(CompanionPresentation.DoublePawBranding.visualText.isEmpty)
        #expect(CompanionPresentation.DoublePawBranding.nonReducedMotionDuration >= 0.5)
        #expect(CompanionPresentation.DoublePawBranding.nonReducedMotionDuration <= 0.8)
    }

    @Test("Adoption keeps the name entered by the user")
    func adoptionUsesCustomName() {
        let now = Date(timeIntervalSince1970: 100)
        let result = FriendMVPReducer.reduce(
            snapshot: .fresh(now: now),
            event: .petAdopted(species: .dog, name: "  Luna  ", at: now)
        )

        #expect(result.snapshot.pet == .dog)
        #expect(result.snapshot.petName == "Luna")
        #expect(result.snapshot.phase == .setup)
        #expect(result.effects == [.persist])
    }

    @Test("Starting a valid session requests protection and freezes one deadline")
    func validSessionStartsProtection() {
        let now = Date(timeIntervalSince1970: 100)
        var snapshot = adoptedSnapshot(now: now)

        let result = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .sessionStarted(
                goal: "Read chapter three",
                goalMode: .specific,
                duration: 30 * 60,
                remindersAvailable: true,
                at: now
            )
        )
        snapshot = result.snapshot

        #expect(snapshot.phase == .focusing)
        #expect(snapshot.goal == "Read chapter three")
        #expect(snapshot.focusDeadline == now.addingTimeInterval(30 * 60))
        #expect(snapshot.focusMonitorID != nil)
        #expect(result.effects.first == .applyProtection)
        #expect(result.effects.last == .persist)
        #expect(result.effects.contains { effect in
            guard case .scheduleFocusDeadline(let monitorID, let deadline) = effect else {
                return false
            }
            return monitorID == snapshot.focusMonitorID && deadline == snapshot.focusDeadline
        })
        #expect(result.effects.contains(.syncLiveActivity))
    }

    @Test("Submitting an access request pauses focus and starts one 60 minute window")
    func accessRequestStartsWindow() {
        let start = Date(timeIntervalSince1970: 100)
        var snapshot = focusingSnapshot(start: start)
        snapshot = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .shieldRequestReceived(at: start.addingTimeInterval(60))
        ).snapshot

        let requestTime = start.addingTimeInterval(120)
        let result = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .accessRequestSubmitted(reason: .studyResearch, at: requestTime)
        )

        #expect(result.snapshot.phase == .accessWindow)
        #expect(result.snapshot.remainingFocusDuration == 28 * 60)
        #expect(result.snapshot.accessDeadline == requestTime.addingTimeInterval(60 * 60))
        #expect(result.snapshot.accessRequestCount == 1)
        #expect(result.effects.first == .cancelFocusDeadline(monitorID: snapshot.focusMonitorID))
        #expect(result.effects.contains(.clearProtection))
        #expect(result.effects.contains(.syncLiveActivity))
        #expect(result.effects.last == .persist)
    }

    @Test("Cancelling an access request keeps protection and focus eligibility unchanged")
    func cancellingAccessRequestHasNoProtectionOrReminderEffects() {
        let start = Date(timeIntervalSince1970: 100)
        let focusing = focusingSnapshot(start: start)
        let requesting = FriendMVPReducer.reduce(
            snapshot: focusing,
            event: .shieldRequestReceived(at: start.addingTimeInterval(15))
        ).snapshot

        let result = FriendMVPReducer.reduce(
            snapshot: requesting,
            event: .accessRequestCancelled(at: start.addingTimeInterval(30))
        )

        #expect(result.snapshot.phase == .focusing)
        #expect(result.snapshot.focusDeadline == focusing.focusDeadline)
        #expect(result.snapshot.focusMonitorID == focusing.focusMonitorID)
        #expect(result.snapshot.accessWindowID == nil)
        #expect(result.snapshot.accessRequestCount == 0)
        #expect(result.snapshot.totalAccessDuration == 0)
        #expect(result.effects == [.persist])
    }

    @Test("Two access windows accumulate duration and receive distinct deadlines")
    func twoAccessWindowsAccumulateDuration() throws {
        let start = Date(timeIntervalSince1970: 100)
        var snapshot = accessWindowSnapshot(start: start)
        let firstWindowID = try #require(snapshot.accessWindowID)

        let firstReturn = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .returnToFocusRequested(at: start.addingTimeInterval(5 * 60))
        )
        snapshot = firstReturn.snapshot

        let secondRequestTime = start.addingTimeInterval(7 * 60)
        snapshot = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .shieldRequestReceived(at: secondRequestTime)
        ).snapshot
        let secondWindow = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .accessRequestSubmitted(reason: .importantMessage, at: secondRequestTime)
        )
        let secondWindowID = try #require(secondWindow.snapshot.accessWindowID)

        #expect(secondWindowID != firstWindowID)
        #expect(secondWindow.snapshot.accessRequestCount == 2)
        #expect(secondWindow.snapshot.accessDeadline == secondRequestTime.addingTimeInterval(60 * 60))

        let secondReturnTime = secondRequestTime.addingTimeInterval(3 * 60)
        let secondReturn = FriendMVPReducer.reduce(
            snapshot: secondWindow.snapshot,
            event: .returnToFocusRequested(at: secondReturnTime)
        )

        #expect(secondReturn.snapshot.phase == .focusing)
        #expect(secondReturn.snapshot.totalAccessDuration == 8 * 60)
        #expect(secondReturn.snapshot.remainingFocusDuration == 28 * 60)
        #expect(secondReturn.snapshot.focusDeadline == secondReturnTime.addingTimeInterval(28 * 60))
        #expect(secondReturn.effects.contains(.reapplyProtection))
        #expect(secondReturn.effects.contains(.cancelAccessReminders(windowID: secondWindowID)))
    }

    @Test("Returning from access creates a fresh focus deadline and requests reapply once")
    func returnToFocusReappliesProtection() {
        let start = Date(timeIntervalSince1970: 100)
        var snapshot = accessWindowSnapshot(start: start)
        let windowID = snapshot.accessWindowID
        let returnedAt = start.addingTimeInterval(5 * 60)

        let result = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .returnToFocusRequested(at: returnedAt)
        )
        snapshot = result.snapshot

        #expect(snapshot.phase == .focusing)
        #expect(snapshot.accessWindowID == nil)
        #expect(snapshot.totalAccessDuration == 5 * 60)
        #expect(snapshot.focusDeadline == returnedAt.addingTimeInterval(snapshot.remainingFocusDuration))
        #expect(snapshot.focusMonitorID != nil)
        #expect(result.effects.first == .cancelFocusDeadline(monitorID: nil))
        #expect(result.effects.contains(.reapplyProtection))
        #expect(result.effects.contains(.cancelAccessReminders(windowID: windowID)))
        #expect(result.effects.contains(.syncLiveActivity))
        #expect(result.effects.last == .persist)
    }

    @Test("A completed focus session adds bond once")
    func completionAddsBondOnce() {
        let start = Date(timeIntervalSince1970: 100)
        let snapshot = focusingSnapshot(start: start)
        let deadline = try! #require(snapshot.focusDeadline)

        let completed = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .reconcile(at: deadline)
        )
        let repeated = FriendMVPReducer.reduce(
            snapshot: completed.snapshot,
            event: .reconcile(at: deadline.addingTimeInterval(1))
        )

        #expect(completed.snapshot.phase == .completed)
        #expect(completed.snapshot.bondPoints == 10)
        #expect(completed.snapshot.completedSessions == 1)
        #expect(completed.effects.contains(.syncLiveActivity))
        #expect(repeated.snapshot.bondPoints == 10)
        #expect(repeated.effects.isEmpty)
    }

    @Test("An expired access window closes gently without completion growth")
    func accessTimeoutDoesNotSettleCompletion() {
        let start = Date(timeIntervalSince1970: 100)
        let snapshot = accessWindowSnapshot(start: start)
        let deadline = try! #require(snapshot.accessDeadline)

        let result = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .reconcile(at: deadline)
        )

        #expect(result.snapshot.phase == .setup)
        #expect(result.snapshot.bondPoints == 0)
        #expect(result.snapshot.completedSessions == 0)
        #expect(result.effects.first == .clearProtection)
    }

    @Test("Access-window reconciliation respects the 59:59 and 60:00 boundary")
    func accessWindowDeadlineBoundary() throws {
        let start = Date(timeIntervalSince1970: 100)
        let snapshot = accessWindowSnapshot(start: start)
        let deadline = try #require(snapshot.accessDeadline)

        let justBeforeDeadline = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .reconcile(at: deadline.addingTimeInterval(-1))
        )
        let atDeadline = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .reconcile(at: deadline)
        )

        #expect(justBeforeDeadline.snapshot == snapshot)
        #expect(justBeforeDeadline.effects.isEmpty)
        #expect(atDeadline.snapshot.phase == .setup)
        #expect(atDeadline.snapshot.bondPoints == 0)
        #expect(atDeadline.snapshot.completedSessions == 0)
        #expect(atDeadline.effects.contains(.clearProtection))
        #expect(atDeadline.effects.contains(.cancelAccessReminders(windowID: snapshot.accessWindowID)))
    }

    @Test("Repeated return requests are idempotent after the window is closed")
    func repeatedReturnIsIdempotent() {
        let start = Date(timeIntervalSince1970: 100)
        let returned = FriendMVPReducer.reduce(
            snapshot: accessWindowSnapshot(start: start),
            event: .returnToFocusRequested(at: start.addingTimeInterval(60))
        )

        let repeated = FriendMVPReducer.reduce(
            snapshot: returned.snapshot,
            event: .returnToFocusRequested(at: start.addingTimeInterval(61))
        )

        #expect(repeated.snapshot == returned.snapshot)
        #expect(repeated.effects.isEmpty)
    }

    @Test("Repeated end requests are idempotent after a session is ended")
    func repeatedEndIsIdempotent() {
        let start = Date(timeIntervalSince1970: 100)
        let ended = FriendMVPReducer.reduce(
            snapshot: focusingSnapshot(start: start),
            event: .sessionEnded(at: start.addingTimeInterval(60))
        )

        let repeated = FriendMVPReducer.reduce(
            snapshot: ended.snapshot,
            event: .sessionEnded(at: start.addingTimeInterval(61))
        )

        #expect(repeated.snapshot == ended.snapshot)
        #expect(repeated.effects.isEmpty)
    }

    @Test("Free focus is stored as an explicit mode")
    func freeFocusStarts() {
        let now = Date(timeIntervalSince1970: 100)
        let result = FriendMVPReducer.reduce(
            snapshot: adoptedSnapshot(now: now),
            event: .sessionStarted(
                goal: "Free focus",
                goalMode: .freeFocus,
                duration: 45 * 60,
                remindersAvailable: true,
                at: now
            )
        )

        #expect(result.snapshot.phase == .focusing)
        #expect(result.snapshot.goalMode == .freeFocus)
        #expect(result.snapshot.goal == "Free focus")
    }

    @Test("Changing companion resets the new relationship without changing phase")
    func changingCompanionStartsNewRelationship() {
        let now = Date(timeIntervalSince1970: 100)
        var snapshot = adoptedSnapshot(now: now)
        snapshot.bondPoints = 40
        snapshot.completedSessions = 4

        let result = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .petChanged(species: .cat, name: "Lily", at: now)
        )

        #expect(result.snapshot.pet == .cat)
        #expect(result.snapshot.petName == "Lily")
        #expect(result.snapshot.bondPoints == 0)
        #expect(result.snapshot.completedSessions == 0)
        #expect(result.snapshot.phase == .setup)
    }

    @Test("Selecting Max from Setup persists the companion through every P0 presentation")
    @MainActor
    func selectingMaxFromSetupPersistsEveryP0Presentation() throws {
        let suiteName = "FriendMVPSetupCompanionSelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FriendMVPStore(defaults: defaults)
        let MiloSetup = FriendMVPReducer.reduce(
            snapshot: .fresh(),
            event: .petAdopted(species: .cat, name: "", at: Date())
        ).snapshot
        store.save(.init(snapshot: MiloSetup, preferences: .fresh()))

        let model = FriendMVPModel(store: store)
        #expect(model.confirmSetupCompanionSelection(.dog))
        #expect(model.snapshot.pet == .dog)
        #expect(model.presentedPetName == "Max")

        let phases: [(FriendMVPPhase, PetMood, String)] = [
            (.setup, .welcome, "FocumiMaxIdle"),
            (.focusing, .focusing, "FocumiMaxFocus"),
            (.requestingAccess, .waiting, "FocumiMaxWaiting"),
            (.accessWindow, .waiting, "FocumiMaxWaiting"),
            (.completed, .celebrating, "FocumiMaxComplete"),
        ]
        for (_, mood, expectedAsset) in phases {
            #expect(CompanionPresentation.displayName(
                for: model.snapshot.pet,
                storedName: model.snapshot.petName
            ) == "Max")
            #expect(CompanionPresentation.assetName(for: .dog, mood: mood) == expectedAsset)
        }

        let restoredModel = FriendMVPModel(store: store)
        #expect(restoredModel.snapshot.pet == .dog)
        #expect(restoredModel.presentedPetName == "Max")
    }

    @Test("Milo remains the consistent companion presentation")
    func MiloRemainsTheConsistentCompanionPresentation() {
        let Milo = FriendMVPReducer.reduce(
            snapshot: .fresh(),
            event: .petAdopted(species: .cat, name: "", at: Date())
        ).snapshot

        #expect(Milo.pet == .cat)
        #expect(CompanionPresentation.displayName(for: Milo.pet, storedName: Milo.petName) == "Milo")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .welcome) == "FocumiMiloIdle")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .focusing) == "FocumiMiloFocus")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .waiting) == "FocumiMiloWaiting")
        #expect(CompanionPresentation.assetName(for: .cat, mood: .celebrating) == "FocumiMiloComplete")
    }

    @Test("Legacy MVP data migrates to the Beta duration set")
    @MainActor
    func legacyDataMigratesToBetaPreferences() throws {
        let suiteName = "FriendMVPStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var legacy = FriendMVPSnapshot.fresh()
        legacy.plannedFocusDuration = 25 * 60
        legacy.remainingFocusDuration = 25 * 60
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: "friend-mvp.snapshot.v1"
        )

        let restored = try loadedState(from: FriendMVPStore(defaults: defaults))

        #expect(restored.snapshot.plannedFocusDuration == 25 * 60)
        #expect(restored.preferences.preferredFocusDuration == 30 * 60)
        #expect(restored.preferences.remainingPetChanges == 1)
    }

    @Test("Product phases keep their relatable pet scenes")
    func phasesMapToRelatableScenes() {
        #expect(PetActivityScene.forPhase(.setup) == .homework)
        #expect(PetActivityScene.forPhase(.focusing) == .computer)
        #expect(PetActivityScene.forPhase(.completed) == .playBall)
        #expect(PetActivityScene.forPhase(.requestingAccess) == .companion)
        #expect(PetActivityScene.forPhase(.accessWindow) == .waiting)
        #expect(PetActivityScene.waiting.presentsReturnCue)
        #expect(!PetActivityScene.computer.presentsReturnCue)
    }

    @Test("Shield companion presentation maps the persisted dog identifier to Max art")
    @MainActor
    func shieldCompanionPresentationUsesOriginalArt() {
        #expect(ShieldCompanionPresentation.iconAssetName(for: "cat") == "FocumiMiloShieldPortrait")
        #expect(ShieldCompanionPresentation.iconAssetName(for: "dog") == "FocumiMaxShieldPortrait")
        #expect(ShieldCompanionPresentation.iconAssetName(for: nil) == "FocumiMiloShieldPortrait")
    }

    @Test("Vintage character poses project the persisted dog identity as Max")
    @MainActor
    func vintagePoseMappingUsesCompanionSpecificAssets() {
        #expect(VintagePetAsset.name(species: .cat, mood: .focusing, activity: .returning, isResponding: false) == "FocumiMiloReturn")
        #expect(VintagePetAsset.name(species: .dog, mood: .focusing, activity: .returning, isResponding: false) == "FocumiMaxReturn")
        #expect(VintagePetAsset.name(species: .cat, mood: .focusing, activity: .starting, isResponding: false) == "FocumiMiloStart")
        #expect(VintagePetAsset.name(species: .cat, mood: .celebrating, activity: .computer, isResponding: false) == "FocumiMiloComplete")
        #expect(VintagePetAsset.name(species: .dog, mood: .focusing, activity: .computer, isResponding: true) == "FocumiMaxTap")
        #expect(UIImage(named: "FocumiMiloReturn") != nil)
        #expect(UIImage(named: "FocumiMaxReturn") != nil)
    }

    @Test("Every retained pet action uses real multi-frame art")
    @MainActor
    func petActionsUseMultiFrameArt() {
        for species in PetSpecies.allCases {
            for clip in PetAnimationClip.allCases {
                let frames = PetFrameAnimation.frameNames(for: species, clip: clip)
                let durations = PetFrameAnimation.frameDurations(for: clip)
                #expect(frames.count >= PetFrameAnimation.minimumFrameCount)
                #expect(Set(frames).count == frames.count)
                #expect(durations.count == frames.count)
                #expect(durations.allSatisfy { $0 > 0 })
                for frame in frames {
                    #expect(UIImage(named: frame) != nil)
                }
            }
        }
    }

    @Test("Celebration animation excludes the two source frames with cropped heads")
    func celebrationAnimationExcludesCroppedSourceFrames() {
        let catFrames = PetFrameAnimation.frameNames(for: .cat, clip: .celebrate)
        let dogFrames = PetFrameAnimation.frameNames(for: .dog, clip: .celebrate)

        #expect(catFrames == ["MiloCelebrate01", "MiloCelebrate02", "MiloCelebrate04"])
        #expect(dogFrames == ["MaxCelebrate01", "MaxCelebrate02", "MaxCelebrate04"])
    }

    @Test("Completion celebration is one 2–4 second, non-reward signature moment")
    func completionCelebrationDurationIsBounded() {
        let duration = PetFrameAnimation.duration(of: .celebrate)

        #expect(duration >= 2)
        #expect(duration <= 4)
        #expect(PetFrameAnimation.frameIndex(for: .celebrate, at: duration * 2, repeats: false) == 2)
    }

    @Test("Returning projection stays neutral and does not claim restored protection")
    func returningLiveActivityProjectionUsesReturningPhase() throws {
        let start = Date(timeIntervalSince1970: 100)
        let snapshot = focusingSnapshot(start: start)
        let state = try #require(
            FocusLiveActivityProjection.contentState(
                from: snapshot,
                presentationPhase: .returning,
                now: start
            )
        )

        #expect(state.phase == .returning)
        #expect(state.goal == snapshot.goal)
        #expect(state.deadline == snapshot.focusDeadline)
    }

    @Test("Live Activity badges use dedicated opaque Milo and Max resources for every honest phase")
    func liveActivityBadgeResourcesMapEveryPhase() {
        #expect(FocusLiveActivityPet.cat.liveActivityBadgeAssetName(for: .focusing) == "FocumiMiloLAFocus")
        #expect(FocusLiveActivityPet.cat.liveActivityBadgeAssetName(for: .waitingToReturn) == "FocumiMiloLAWaiting")
        #expect(FocusLiveActivityPet.cat.liveActivityBadgeAssetName(for: .returning) == "FocumiMiloLAReturning")
        #expect(FocusLiveActivityPet.dog.liveActivityBadgeAssetName(for: .focusing) == "FocumiMaxLAFocus")
        #expect(FocusLiveActivityPet.dog.liveActivityBadgeAssetName(for: .waitingToReturn) == "FocumiMaxLAWaiting")
        #expect(FocusLiveActivityPet.dog.liveActivityBadgeAssetName(for: .returning) == "FocumiMaxLAReturning")
        #expect(FocusLiveActivityPet.dog.liveActivityFallbackAssetName == "FocumiMaxLAFocus")
    }

    @Test("Live Activity presentation labels stay honest while returning")
    func liveActivityPresentationAvoidsRestoredProtectionClaims() {
        let english = Locale(identifier: "en")
        func resolve(_ resource: LocalizedStringResource) -> String {
            var localizedResource = resource
            localizedResource.locale = english
            return String(localized: localizedResource)
        }

        #expect(resolve(FocusLiveActivityPhase.focusing.statusText) == "Focus together")
        #expect(resolve(FocusLiveActivityPhase.waitingToReturn.statusText) == "Your page is held")
        #expect(resolve(FocusLiveActivityPhase.returning.statusText) == "Requesting focus again")
        #expect(resolve(FocusLiveActivityPhase.returning.compactStatusText) == "Requesting")
    }

    @Test("End confirmation is presentation-only and requires its final explicit action")
    func endConfirmationRequiresExplicitFinalAction() {
        var confirmation = FocusEndConfirmationState()

        #expect(!confirmation.isPresented)
        let didEndWithoutPresentation = confirmation.confirmEnd()
        #expect(!didEndWithoutPresentation)

        confirmation.request()
        #expect(confirmation.isPresented)
        confirmation.continueFocusing()
        #expect(!confirmation.isPresented)
        let didEndAfterContinue = confirmation.confirmEnd()
        #expect(!didEndAfterContinue)

        confirmation.request()
        let didConfirmEnd = confirmation.confirmEnd()
        #expect(didConfirmEnd)
        #expect(!confirmation.isPresented)
    }

    @Test("Focus dynamic companion copy resolves from the String Catalog in English and Simplified Chinese")
    func focusDynamicCompanionCopyUsesLocalizedFormat() {
        let english = FocusPresentationCopy.focusHeader(
            petName: "Max",
            locale: Locale(identifier: "en")
        )
        let chinese = FocusPresentationCopy.focusHeader(
            petName: "Max",
            locale: Locale(identifier: "zh-Hans")
        )

        #expect(english == "Max is here, working on this with you")
        #expect(chinese == "Max 正陪你一起做这件事")
    }

    @Test("Visible duration labels use min in English and 分钟 in Chinese")
    func durationLabelsUseTheFrozenLanguageUnits() {
        let english = Locale(identifier: "en")
        let chinese = Locale(identifier: "zh-Hant")

        #expect(FocusPresentationCopy.durationLabel(minutes: 25, locale: english) == "25 min")
        #expect(FocusPresentationCopy.durationLabel(minutes: 45, locale: english) == "45 min")
        #expect(FocusPresentationCopy.durationLabel(minutes: 60, locale: english) == "60 min")
        #expect(FocusPresentationCopy.durationLabel(minutes: 120, locale: english) == "120 min")
        #expect(FocusPresentationCopy.durationLabel(minutes: 120, locale: chinese) == "2 小时")
        #expect(FocusPresentationCopy.durationLabel(minutes: 45, locale: chinese) == "45 分钟")
    }

    @Test("Interface language follows Chinese system languages and otherwise uses English")
    func interfaceLanguageFollowsSystemLanguageFamily() {
        for systemLanguage in ["zh", "zh-Hans", "zh-Hant", "zh-Hant-TW"] {
            let locale = FocumiInterfaceLanguage.resolvedLocale(
                selection: FocumiInterfaceLanguage.system.rawValue,
                systemPreferredLanguages: [systemLanguage]
            )
            #expect(locale.identifier.lowercased().hasPrefix("zh"))
        }

        for systemLanguage in ["en-US", "fr-FR", "ja-JP"] {
            let locale = FocumiInterfaceLanguage.resolvedLocale(
                selection: FocumiInterfaceLanguage.system.rawValue,
                systemPreferredLanguages: [systemLanguage]
            )
            #expect(locale.identifier.lowercased().hasPrefix("en"))
        }
    }

    @Test("Explicit interface language overrides the system choice and restores from preferences")
    func interfaceLanguageOverridePersistsAndRestores() throws {
        let suiteName = "FocumiInterfaceLanguageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(FocumiInterfaceLanguage.chinese.rawValue, forKey: FocumiInterfaceLanguage.storageKey)
        let restoredChinese = try #require(defaults.string(forKey: FocumiInterfaceLanguage.storageKey))
        #expect(
            FocumiInterfaceLanguage.resolvedLocale(
                selection: restoredChinese,
                systemPreferredLanguages: ["en-US"]
            ).identifier.lowercased().hasPrefix("zh")
        )

        defaults.set(FocumiInterfaceLanguage.english.rawValue, forKey: FocumiInterfaceLanguage.storageKey)
        let restoredEnglish = try #require(defaults.string(forKey: FocumiInterfaceLanguage.storageKey))
        #expect(
            FocumiInterfaceLanguage.resolvedLocale(
                selection: restoredEnglish,
                systemPreferredLanguages: ["zh-Hant"]
            ).identifier.lowercased().hasPrefix("en")
        )
    }

    @Test("Production settings expose only the four frozen user-facing sections")
    func productionSettingsExposeOnlyTheFrozenSections() {
        #expect(FocumiSettingsPresentation.productionItems == [
            .companion,
            .language,
            .focusMusic,
            .permissions,
        ])
        #expect(FocumiSettingsPresentation.hiddenItems == [
            .relationshipStage,
            .completedFocusSessions,
            .timeTogether,
            .sharedMemories,
            .defaultFocusDuration,
            .localData,
            .technicalDiagnostics,
        ])
        #expect(FocumiSettingsPresentation.productionItems.union(FocumiSettingsPresentation.hiddenItems) == Set(FocumiSettingsPresentation.Item.allCases))
    }

    @Test("Settings catalog resolves the language choice in Chinese")
    func settingsCatalogResolvesLanguageChoice() {
        #expect(String(localized: "Language", locale: Locale(identifier: "zh-Hans")) == "语言")
        #expect(String(localized: "Follow System", locale: Locale(identifier: "zh-Hans")) == "跟随系统")
    }

    @Test("Settings uses the selected app locale for visible copy and the current companion")
    func settingsCopyUsesTheSelectedAppLocale() {
        let english = Locale(identifier: "en")
        let chinese = Locale(identifier: "zh-Hans")

        #expect(FocumiSettingsCopy.text("Settings", locale: english) == "Settings")
        #expect(FocumiSettingsCopy.text("Close", locale: english) == "Close")
        #expect(FocumiSettingsCopy.text("First hello", locale: english) == "First hello")
        #expect(FocumiSettingsCopy.text("Enabled", locale: english) == "Enabled")
        #expect(FocumiSettingsCopy.text("Settings", locale: chinese) == "设置")
        #expect(FocumiSettingsCopy.text("Close", locale: chinese) == "关闭")
        #expect(FocumiSettingsCopy.text("Screen Time", locale: chinese) == "屏幕使用时间")
        #expect(FocumiSettingsCopy.text("Focus music", locale: english) == "Focus music")
        #expect(FocumiSettingsCopy.text("Focus music", locale: chinese) == "专注音乐")
        #expect(CompanionPresentation.displayName(for: .cat) == "Milo")
        #expect(CompanionPresentation.displayName(for: .dog) == "Max")
        #expect(FocumiSettingsCopy.text("Not requested", locale: english) == "Not requested")
        #expect(FocumiSettingsCopy.text("Permission needed", locale: chinese) == "需要授权")
        #expect(FocumiSettingsCopy.text("Enabled", locale: chinese) == "已开启")
        #expect(FocumiSettingsCopy.text("Disabled", locale: chinese) == "未开启")
    }

    @Test("Settings dynamic relationship stages and music tracks use the selected app locale")
    func settingsDynamicValuesUseTheSelectedAppLocale() {
        let english = Locale(identifier: "en")
        let chinese = Locale(identifier: "zh-Hans")
        let relationshipStages: [(CompanionRelationshipStage, String, String)] = [
            (.firstHello, "Just met", "初次相识"),
            (.gettingAcquainted, "Getting acquainted", "渐渐熟悉"),
            (.growingTrust, "Growing trust", "彼此信赖"),
            (.inSync, "In sync", "默契伙伴"),
            (.lastingCompanions, "Lasting companions", "长久陪伴"),
        ]
        let musicTracks: [(FocusMusicTrack, String, String)] = [
            (.firstLight, "First Light", "晨光"),
            (.budding, "Budding", "新芽"),
            (.deepBlue, "Deep Blue", "深蓝"),
        ]

        #expect(relationshipStages.map(\.0) == CompanionRelationshipStage.allCases)
        #expect(musicTracks.map(\.0) == FocusMusicTrack.allCases)

        for (stage, englishName, chineseName) in relationshipStages {
            #expect(FocumiSettingsCopy.relationshipStageName(stage, locale: english) == englishName)
            #expect(FocumiSettingsCopy.relationshipStageName(stage, locale: chinese) == chineseName)
        }

        for (track, englishName, chineseName) in musicTracks {
            #expect(FocumiSettingsCopy.musicTrackName(track, locale: english) == englishName)
            #expect(FocumiSettingsCopy.musicTrackName(track, locale: chinese) == chineseName)
        }
    }

    @Test("Pact readiness uses an honest compact presentation for each required setup state")
    func pactReadinessPresentationIsCompactAndHonest() {
        #expect(FocusPactReadinessPresentation.make(isScreenTimeApproved: false, selectedAppCount: 12) == .needsScreenTime)
        #expect(FocusPactReadinessPresentation.make(isScreenTimeApproved: true, selectedAppCount: 0) == .needsApps)
        #expect(FocusPactReadinessPresentation.make(isScreenTimeApproved: true, selectedAppCount: 13) == .ready(selectedApps: 13))
        #expect(FocusPactReadinessPresentation.ready(selectedApps: 13).iconKind == .pawStamp)
        #expect(FocusPactReadinessPresentation.needsApps.iconKind == .bookmarkPaw)
    }

    @Test("Companion copy uses shared-page language rather than mechanical guard language")
    func companionCopyUsesSharedPageLanguage() {
        #expect(!FocusPresentationCopy.focusHeader(petName: "Milo", locale: Locale(identifier: "zh-Hans")).contains("守住"))
        #expect(!FocusPresentationCopy.returnNotice(petName: "Max", locale: Locale(identifier: "zh-Hans")).contains("守住"))
        #expect(FocusPresentationCopy.completionMessage(petName: "Milo", locale: Locale(identifier: "zh-Hans")) == "Milo 陪你完成了这次专注。")
        #expect(FocusPresentationCopy.selectedDistractingApps(count: 13, locale: Locale(identifier: "zh-Hans")) == "已选择 13 个容易分心的 App")
    }

    @Test("The hand-drawn companion icon set covers Pact readiness and settings without SF symbols")
    func companionIconKindsCoverTheVisiblePactRoles() {
        let kinds: [FocumiCompanionIconKind] = [.bookmarkPaw, .pageTurn, .companionClock, .pencilBloom, .pawStamp, .settingsPage]
        #expect(kinds.count == 6)
        #expect(kinds.contains(FocusPactReadinessPresentation.ready(selectedApps: 1).iconKind))
    }

    @Test("Free companion changes archive the old relationship and preserve legacy allowance data")
    @MainActor
    func oneCompanionChangePersistsMemory() throws {
        let suiteName = "FriendMVPChangeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FriendMVPStore(defaults: defaults)
        var snapshot = adoptedSnapshot(now: Date(timeIntervalSince1970: 100))
        snapshot.bondPoints = 40
        snapshot.completedSessions = 4
        var preferences = FriendBetaPreferences.fresh()
        preferences.currentPetFocusedDuration = 7_200
        store.save(.init(snapshot: snapshot, preferences: preferences))

        let model = FriendMVPModel(store: store)
        #expect(model.changePet(to: .cat, name: "") == true)
        #expect(model.snapshot.pet == .cat)
        #expect(model.snapshot.petName == "Milo")
        #expect(model.snapshot.bondPoints == 0)
        #expect(model.preferences.remainingPetChanges == 1)
        #expect(model.preferences.archivedPetMemory?.name == "Max")
        #expect(model.preferences.archivedPetMemory?.bondPoints == 40)
        #expect(model.preferences.archivedPetMemory?.focusedDuration == 7_200)
        #expect(model.changePet(to: .dog, name: "Max") == true)
        #expect(model.snapshot.pet == .dog)
        #expect(model.preferences.remainingPetChanges == 1)

        let reloaded = try loadedState(from: store)
        #expect(reloaded.snapshot.pet == .dog)
        #expect(reloaded.preferences.remainingPetChanges == 1)
        #expect(reloaded.preferences.archivedPetMemory?.name == "Milo")
    }

    @Test("Single paper preferences ignore a legacy theme value and keep music choices")
    @MainActor
    func betaPreferencesIgnoreLegacyThemeAndPersistTogether() throws {
        let suiteName = "FriendMVPPreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FriendMVPStore(defaults: defaults)
        let model = FriendMVPModel(store: store)
        model.setPreferredDuration(120 * 60)
        model.setMusicTrack(.deepBlue)
        model.setMusicVolume(0.72)

        let persisted = try loadedState(from: store)
        let encoded = try JSONEncoder().encode(persisted)
        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var legacyPreferences = try #require(legacyObject["preferences"] as? [String: Any])
        legacyPreferences["themeMode"] = "dark"
        legacyObject["preferences"] = legacyPreferences
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let reloaded = try JSONDecoder().decode(FriendBetaPersistedState.self, from: legacyData)

        #expect(reloaded.preferences.preferredFocusDuration == 120 * 60)
        #expect(reloaded.preferences.selectedMusicTrack == .deepBlue)
        #expect(reloaded.preferences.musicVolume == 0.72)
    }

    @Test("Focus music surfaces an unavailable bundled resource instead of claiming playback")
    @MainActor
    func focusMusicSurfacesMissingResource() async {
        let audio = FocusAudioClient(dataAssetProvider: { _ in nil })
        var preferences = FriendBetaPreferences.fresh()
        preferences.musicEnabled = true

        audio.sync(preferences: preferences, phase: .focusing)
        audio.setAppActive(true)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(audio.playbackState == .failed(.assetUnavailable))
    }

    @Test("New companions begin with music while a manual mute remains persisted")
    @MainActor
    func musicDefaultsOnAndManualMutePersists() throws {
        let suiteName = "FriendMVPMusicPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FriendMVPStore(defaults: defaults)
        let model = FriendMVPModel(
            store: store,
            focusAudio: FocusAudioClient(dataAssetProvider: { _ in nil })
        )
        #expect(model.preferences.musicEnabled)

        model.setMusicEnabled(false)
        let reloaded = try loadedState(from: store)
        #expect(reloaded.preferences.musicEnabled == false)
    }

    @Test("Music route stays continuous through the access and return loop")
    func musicRouteProjectsOnlyPresentationState() {
        var preferences = FriendBetaPreferences.fresh()
        preferences.selectedMusicTrack = .budding

        #expect(FocumiAudioRouting.program(
            phase: .setup,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .homeAmbience)
        #expect(FocumiAudioRouting.program(
            phase: .focusing,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .focusSoundscape(.budding))
        #expect(FocumiAudioRouting.program(
            phase: .accessWindow,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .focusSoundscape(.budding))
        #expect(FocumiAudioRouting.program(
            phase: .completed,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .completionCue)
        #expect(FocumiAudioRouting.program(
            phase: .completed,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: true
        ) == .homeAmbience)
    }

    @Test("Music routing never activates while muted, inactive, or before first presentation")
    func musicRouteGuardsLifecycleAndManualMute() {
        var preferences = FriendBetaPreferences.fresh()
        preferences.musicEnabled = false
        #expect(FocumiAudioRouting.program(
            phase: .focusing,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .stopped)

        preferences.musicEnabled = true
        #expect(FocumiAudioRouting.program(
            phase: .focusing,
            preferences: preferences,
            appIsActive: false,
            presentationIsReady: true,
            completionCueHasPlayed: false
        ) == .stopped)
        #expect(FocumiAudioRouting.program(
            phase: .setup,
            preferences: preferences,
            appIsActive: true,
            presentationIsReady: false,
            completionCueHasPlayed: false
        ) == .stopped)
    }

    @Test("Music program gains preserve the saved volume while keeping Home quieter than Focus")
    func musicProgramGainsPreserveRelativeVolume() {
        #expect(abs(FocumiAudioRouting.targetVolume(for: .homeAmbience, userVolume: 0.85) - 0.2125) < 0.0001)
        #expect(abs(FocumiAudioRouting.targetVolume(for: .focusSoundscape(.deepBlue), userVolume: 0.85) - 0.323) < 0.0001)
        #expect(abs(FocumiAudioRouting.targetVolume(for: .focusSoundscape(.deepBlue), userVolume: 0.4) - 0.152) < 0.0001)
    }

    @Test("Default Home and Focus music use distinct published CC0 assets")
    func defaultMusicAssetsAreDistinctAndAudiblyRouted() {
        let preferences = FriendBetaPreferences.fresh()
        #expect(preferences.selectedMusicTrack == .deepBlue)
        #expect(FocumiAudioRouting.assetName(for: .homeAmbience) == "FirstLightSlow")
        #expect(FocumiAudioRouting.assetName(for: .focusSoundscape(preferences.selectedMusicTrack)) == "DeepBlueSlow")
        #expect(FocumiAudioRouting.assetName(for: .completionCue) == "BuddingSlow")
        #expect(FocumiAudioRouting.hasVerifiedPlayback(
            isPlaying: true,
            startTime: 1,
            currentTime: 1.2,
            volume: 0.2
        ))
        #expect(!FocumiAudioRouting.hasVerifiedPlayback(
            isPlaying: true,
            startTime: 1,
            currentTime: 1,
            volume: 0.2
        ))
    }

    @Test("Legacy music identifiers migrate to the replacement tracks")
    func legacyMusicIdentifiersMigrate() throws {
        let decoder = JSONDecoder()

        let formerGentle = try decoder.decode(
            FocusMusicTrack.self,
            from: Data("\"gentlePiano\"".utf8)
        )
        let formerAmbient = try decoder.decode(
            FocusMusicTrack.self,
            from: Data("\"quietAmbient\"".utf8)
        )

        #expect(formerGentle == .firstLight)
        #expect(formerAmbient == .deepBlue)
    }

    @Test("Frame timing loops and one-shot reactions stay deterministic")
    func frameTimingIsDeterministic() {
        let cycle = PetFrameAnimation.duration(of: .idle)

        #expect(PetFrameAnimation.frameIndex(for: .idle, at: 0) == 0)
        #expect(PetFrameAnimation.frameIndex(for: .idle, at: 2.81) == 1)
        #expect(PetFrameAnimation.frameIndex(for: .idle, at: 2.93) == 2)
        #expect(PetFrameAnimation.frameIndex(for: .idle, at: cycle) == 0)
        #expect(PetFrameAnimation.frameIndex(for: .tap, at: 100, repeats: false) == 3)
    }

    @Test("Product scenes select the matching real animation clip")
    func scenesSelectAnimationClips() {
        #expect(PetFrameAnimation.baseClip(for: .companion) == .idle)
        #expect(PetFrameAnimation.baseClip(for: .homework) == .focus)
        #expect(PetFrameAnimation.baseClip(for: .computer) == .focus)
        #expect(PetFrameAnimation.baseClip(for: .playBall) == .celebrate)
    }

    @Test("Beta exposes exactly the four confirmed focus durations")
    func betaUsesConfirmedDurations() {
        let expected: [TimeInterval] = [
            30 * 60,
            45 * 60,
            60 * 60,
            120 * 60,
        ]
        #expect(FriendBetaPreferences.supportedFocusDurations == expected)
    }

    @Test("Unreadable Beta data is preserved and requires an explicit recovery choice")
    @MainActor
    func unreadableDataRequiresRecovery() throws {
        let suiteName = "FriendMVPCorruptStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let unreadable = Data("not-json".utf8)
        defaults.set(unreadable, forKey: "friend-beta.state.v2")

        let result = FriendMVPStore(defaults: defaults).loadState()

        #expect(result == .recoveryRequired)
        #expect(defaults.data(forKey: "friend-beta.state.v2") == unreadable)
    }

    @Test("Relationship stages advance only after completed sessions")
    func relationshipStagesUseCompletedSessions() {
        #expect(CompanionRelationshipStage.stage(completedSessions: 0) == .firstHello)
        #expect(CompanionRelationshipStage.stage(completedSessions: 1) == .gettingAcquainted)
        #expect(CompanionRelationshipStage.stage(completedSessions: 5) == .growingTrust)
        #expect(CompanionRelationshipStage.stage(completedSessions: 15) == .inSync)
        #expect(CompanionRelationshipStage.stage(completedSessions: 30) == .lastingCompanions)
    }

    @Test("Focus deadline monitoring always uses an Apple-valid interval")
    @MainActor
    func focusDeadlineMonitoringUsesMinimumInterval() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let longDeadline = now.addingTimeInterval(30 * 60)
        let shortDeadline = now.addingTimeInterval(5 * 60)

        let longInterval = try #require(
            FocusDeadlineMonitorClient.scheduleInterval(deadline: longDeadline, now: now)
        )
        let shortInterval = try #require(
            FocusDeadlineMonitorClient.scheduleInterval(deadline: shortDeadline, now: now)
        )

        #expect(longInterval.start == now)
        #expect(longInterval.duration == 30 * 60)
        #expect(shortInterval.duration == FocusDeadlineMonitorClient.minimumScheduleDuration)
        #expect(shortInterval.contains(now))
        #expect(FocusDeadlineMonitorClient.scheduleInterval(deadline: now, now: now) == nil)
    }

    @Test("Live Activity mirrors the active focus without owning its deadline")
    func liveActivityProjectsFocusState() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        var snapshot = focusingSnapshot(start: now)
        snapshot.pet = .cat
        snapshot.petName = "Milo"
        snapshot.goal = "Finish chapter three"

        let state = try #require(
            FocusLiveActivityProjection.contentState(from: snapshot, now: now)
        )

        #expect(state.pet == .cat)
        #expect(state.petName == "Milo")
        #expect(state.goal == "Finish chapter three")
        #expect(state.phase == .focusing)
        #expect(state.deadline == snapshot.focusDeadline)
    }

    @Test("Live Activity switches to the gentle return state during access")
    func liveActivityProjectsAccessWindow() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let snapshot = accessWindowSnapshot(start: now)

        let state = try #require(
            FocusLiveActivityProjection.contentState(from: snapshot, now: now)
        )

        #expect(state.pet == .dog)
        #expect(state.petName == "Max")
        #expect(state.phase == .waitingToReturn)
        #expect(state.deadline == snapshot.accessDeadline)
    }

    @Test("Live Activity ends for inactive or expired sessions")
    func liveActivityRejectsInactiveState() {
        let now = Date(timeIntervalSince1970: 10_000)
        let setup = adoptedSnapshot(now: now)
        var expired = focusingSnapshot(start: now)
        expired.focusDeadline = now

        #expect(FocusLiveActivityProjection.contentState(from: setup, now: now) == nil)
        #expect(FocusLiveActivityProjection.contentState(from: expired, now: now) == nil)
    }

    @Test("Presentation keeps persisted dog identity compatible while displaying Max")
    func dogPresentationUsesMaxWithoutMigration() {
        #expect(CompanionPresentation.displayName(for: .dog, storedName: "Max") == "Max")
        #expect(CompanionPresentation.displayName(for: .dog, storedName: "Custom name") == "Max")
        #expect(CompanionPresentation.displayName(for: .cat, storedName: "") == "Milo")

        let dogAssets = [
            VintagePetAsset.name(species: .dog, mood: .focusing, activity: .homework, isResponding: false),
            FocusLiveActivityPet.dog.liveActivityBadgeAssetName(for: .focusing),
            ShieldCompanionPresentation.iconAssetName(for: "dog")
        ]
        #expect(dogAssets.allSatisfy { $0.hasPrefix("FocumiMax") })
        #expect(dogAssets.allSatisfy { !$0.localizedCaseInsensitiveContains("toto") })
    }

    @Test("Only a return to focus creates a performance cue")
    func performanceCuesOnlyPresentTheApprovedReturnRecognition() {
        var coordinator = CompanionPerformanceCoordinator()

        #expect(coordinator.cue(from: .setup, to: .focusing, reduceMotion: false) == nil)
        #expect(coordinator.cue(from: .setup, to: .focusing, reduceMotion: false) == nil)
        #expect(coordinator.cue(from: .focusing, to: .focusing, reduceMotion: false) == nil)

        let returning = coordinator.cue(from: .accessWindow, to: .focusing, reduceMotion: false)
        #expect(returning?.state == .reopeningPage)
        #expect(returning?.token == 1)
        #expect(coordinator.cue(from: .focusing, to: .completed, reduceMotion: false) == nil)

        var reduceMotionCoordinator = CompanionPerformanceCoordinator()
        #expect(reduceMotionCoordinator.cue(from: .accessWindow, to: .focusing, reduceMotion: true) == nil)
    }

    @Test("Return signature keeps per-pet production routing and a static Reduce Motion landing")
    func returnSignatureAnimationRoutesIndependentlyWithoutChangingTruth() {
        #expect(ReturnSignatureAnimation.framesPerSecond == 12)
        #expect(ReturnSignatureAnimation.frameCount == 12)
        #expect(ReturnSignatureAnimation.duration > 2.3)
        #expect(ReturnSignatureAnimation.duration < 3.2)
        #expect(ReturnSignatureAnimation.frameNumber(at: 0) == 1)
        #expect(ReturnSignatureAnimation.frameNumber(at: ReturnSignatureAnimation.duration + 1) == 12)
        #expect(ReturnSignatureAnimation.assetName(for: .cat, frameNumber: 6) == "FocumiMiloReturnSignature006")
        #expect(ReturnSignatureAnimation.assetName(for: .dog, frameNumber: 6) == "FocumiMaxReturnSignature006")
        #expect(ReturnSignatureAnimation.reduceMotionLandingAssetName(for: .cat) == "FocumiMiloFocus")
        #expect(ReturnSignatureAnimation.reduceMotionLandingAssetName(for: .dog) == "FocumiMaxFocus")

        // Presentation metadata remains separate from the reducer's authoritative phase.
        let snapshot = focusingSnapshot(start: Date(timeIntervalSince1970: 2_000))
        #expect(snapshot.phase == .focusing)
        #expect(snapshot.completedSessions == 0)
    }

    @Test("Phase 1 performance manifests retain per-companion fixed anchors")
    func phaseOnePerformanceManifestsAreIndependentAndFixed() {
        let milo = CompanionPerformanceManifest.forSpecies(.cat)
        let max = CompanionPerformanceManifest.forSpecies(.dog)

        #expect(milo.character == "Milo")
        #expect(max.character == "Max")
        #expect(milo.canvasSide == 1254)
        #expect(max.canvasSide == 1254)
        #expect(milo.rootAnchor.contains("book spine"))
        #expect(max.rootAnchor.contains("book spine"))
        #expect(milo.bookOrGroundReference.contains("sage"))
        #expect(max.bookOrGroundReference.contains("dusty-blue"))
        #expect(milo.rootAnchorY != max.rootAnchorY)
        #expect(milo.idlePeriod != max.idlePeriod)
        #expect(milo.completionDuration != max.completionDuration)
    }

    @Test("Phase 1 performance covers every visible character beat without moving its root")
    func phaseOnePerformanceIsContinuousAndRootCompensated() {
        for species in PetSpecies.allCases {
            let manifest = CompanionPerformanceManifest.forSpecies(species)
            #expect(manifest.beat(for: .welcome, activity: .companion) == .idleBreathing)
            #expect(manifest.beat(for: .welcome, activity: .homework) == .pageAttention)
            #expect(manifest.beat(for: .focusing, activity: .computer) == .focusedBreathing)
            #expect(manifest.beat(for: .waiting, activity: .waiting) == .waitingBreathing)
            #expect(manifest.beat(for: .celebrating, activity: .playBall) == .completionReaction)

            let idle = manifest.pose(for: .idleBreathing, elapsed: manifest.idlePeriod / 4, repeats: true)
            #expect(idle.verticalScale > 1)
            #expect(manifest.compensatedYOffset(for: idle.verticalScale, renderedSide: 280) > 0)

            let completionStart = manifest.pose(for: .completionReaction, elapsed: 0, repeats: false)
            let completionPeak = manifest.pose(
                for: .completionReaction,
                elapsed: manifest.completionDuration / 2,
                repeats: false
            )
            let completionEnd = manifest.pose(
                for: .completionReaction,
                elapsed: manifest.completionDuration,
                repeats: false
            )
            #expect(completionStart == .identity)
            #expect(completionPeak.verticalScale > 1)
            #expect(completionEnd == .identity)
        }
    }

    @Test("Companion access copy keeps dynamic names localized without claiming protection success")
    func accessRequestCopyUsesLocalizedCompanionNameAndNeutralTruth() {
        let chinese = Locale(identifier: "zh-Hans")
        #expect(FocusPresentationCopy.accessRequestHeader(petName: "Milo", locale: chinese) == "Milo 在这里等你")
        #expect(FocusPresentationCopy.accessRequestInstruction(petName: "Milo", locale: chinese).contains("Milo"))
        #expect(!FocusPresentationCopy.accessRequestInstruction(petName: "Milo", locale: chinese).localizedCaseInsensitiveContains("已恢复"))
    }

    @Test("Completion presentation does not settle a session")
    func completionPresentationDoesNotChangeReducerTruth() {
        let snapshot = focusingSnapshot(start: Date(timeIntervalSince1970: 1_000))
        #expect(snapshot.phase == .focusing)
        #expect(snapshot.completedSessions == 0)
    }

    private func adoptedSnapshot(now: Date) -> FriendMVPSnapshot {
        FriendMVPReducer.reduce(
            snapshot: .fresh(now: now),
            event: .petAdopted(species: .dog, name: "Max", at: now)
        ).snapshot
    }

    private func focusingSnapshot(start: Date) -> FriendMVPSnapshot {
        FriendMVPReducer.reduce(
            snapshot: adoptedSnapshot(now: start),
            event: .sessionStarted(
                goal: "Review notes",
                goalMode: .specific,
                duration: 30 * 60,
                remindersAvailable: true,
                at: start
            )
        ).snapshot
    }

    private func accessWindowSnapshot(start: Date) -> FriendMVPSnapshot {
        var snapshot = focusingSnapshot(start: start)
        snapshot = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .shieldRequestReceived(at: start)
        ).snapshot
        return FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .accessRequestSubmitted(reason: .urgentMatter, at: start)
        ).snapshot
    }

    @MainActor
    private func loadedState(from store: FriendMVPStore) throws -> FriendBetaPersistedState {
        guard case .loaded(let state) = store.loadState() else {
            Issue.record("Expected a readable persisted state")
            throw FriendMVPStoreTestError.recoveryRequired
        }
        return state
    }
}

private enum FriendMVPStoreTestError: Error {
    case recoveryRequired
}

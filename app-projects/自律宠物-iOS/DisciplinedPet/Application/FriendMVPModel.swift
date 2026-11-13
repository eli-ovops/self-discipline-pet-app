import AVFoundation
import DeviceActivity
import Foundation
import Observation
import OSLog
import UIKit

#if DEBUG
/// DEBUG-only, non-sensitive trace for the Setup companion confirmation seam.
/// It records only species/phase/boolean guard facts and never a goal,
/// selection payload, authorization detail, account, or user-entered text.
@MainActor
enum CompanionConfirmationDebugTrace {
    private struct Record: Encodable {
        let eventID: UInt64
        let monotonicMilliseconds: UInt64
        let selectedPet: String
        let snapshotPet: String
        let remainingPetChanges: Int
        let phase: String
        let guardResult: Bool?
        let presentation: Bool
        let errorCategory: String

        enum CodingKeys: String, CodingKey {
            case eventID = "event_id"
            case monotonicMilliseconds = "monotonic_milliseconds"
            case selectedPet = "selected_pet"
            case snapshotPet = "snapshot_pet"
            case remainingPetChanges = "remaining_pet_changes"
            case phase
            case guardResult = "guard_result"
            case presentation
            case errorCategory = "error_category"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(eventID, forKey: .eventID)
            try container.encode(monotonicMilliseconds, forKey: .monotonicMilliseconds)
            try container.encode(selectedPet, forKey: .selectedPet)
            try container.encode(snapshotPet, forKey: .snapshotPet)
            try container.encode(remainingPetChanges, forKey: .remainingPetChanges)
            try container.encode(phase, forKey: .phase)
            if let guardResult {
                try container.encode(guardResult, forKey: .guardResult)
            } else {
                try container.encodeNil(forKey: .guardResult)
            }
            try container.encode(presentation, forKey: .presentation)
            try container.encode(errorCategory, forKey: .errorCategory)
        }
    }

    private struct Context {
        var selectedPet: String
        var snapshotPet: String
        var remainingPetChanges: Int
        var phase: String
        var presentation: Bool
    }

    private static var nextEventID: UInt64 = 0
    private static var contexts: [UInt64: Context] = [:]
    private static let maximumTraceBytes = 16 * 1024

    static func resetForLaunch() {
        nextEventID = 0
        contexts = [:]
        guard let url = traceURL else { return }
        try? FileManager.default.removeItem(at: url)
        appendToSandbox(
            eventID: 0,
            context: .init(
                selectedPet: "none",
                snapshotPet: "none",
                remainingPetChanges: 0,
                phase: "unknown",
                presentation: false
            ),
            guardResult: nil,
            errorCategory: "none"
        )
    }

    static func begin(
        selectedPet: PetSpecies,
        snapshotPet: PetSpecies?,
        remainingPetChanges: Int,
        phase: FriendMVPPhase,
        isPresented: Bool,
        dataRecoveryNeeded: Bool,
        openingOverlayVisible: Bool,
        secondaryPresentationVisible: Bool
    ) -> UInt64 {
        nextEventID &+= 1
        let eventID = nextEventID
        contexts[eventID] = .init(
            selectedPet: speciesCode(selectedPet),
            snapshotPet: speciesCode(snapshotPet),
            remainingPetChanges: remainingPetChanges,
            phase: phaseCode(phase),
            presentation: isPresented
        )
        emit(
            eventID,
            step: "button-entry",
            details: "selected=\(speciesCode(selectedPet)) snapshot=\(speciesCode(snapshotPet)) remaining=\(remainingPetChanges) phase=\(phaseCode(phase)) presented=\(isPresented) recovery=\(dataRecoveryNeeded) openingOverlay=\(openingOverlayVisible) secondaryPresentation=\(secondaryPresentationVisible)"
        )
        return eventID
    }

    static func emit(_ eventID: UInt64, step: String, details: String) {
        print("[FocumiCompanionConfirm][id=\(eventID)][\(step)] \(details)")
        var context = contexts[eventID] ?? .init(
            selectedPet: "none",
            snapshotPet: "none",
            remainingPetChanges: 0,
            phase: "unknown",
            presentation: false
        )
        if let selectedPet = value(for: "selected", in: details) {
            context.selectedPet = selectedPet
        }
        if let snapshotPet = value(for: "snapshot", in: details) {
            context.snapshotPet = snapshotPet
        }
        if let remainingPetChanges = value(for: "remaining", in: details).flatMap(Int.init) {
            context.remainingPetChanges = remainingPetChanges
        }
        if let phase = value(for: "phase", in: details) {
            context.phase = phase
        }
        if let presentation = value(for: "presented", in: details).flatMap(Bool.init) {
            context.presentation = presentation
        }
        contexts[eventID] = context
        appendToSandbox(
            eventID: eventID,
            context: context,
            guardResult: boolValue(in: details),
            errorCategory: value(for: "reason", in: details) ?? "none"
        )
    }

    static func speciesCode(_ species: PetSpecies?) -> String {
        switch species {
        case .cat: "milo"
        case .dog: "max"
        case nil: "none"
        }
    }

    static func phaseCode(_ phase: FriendMVPPhase) -> String {
        switch phase {
        case .onboarding: "onboarding"
        case .setup: "setup"
        case .focusing: "focusing"
        case .requestingAccess: "requestingAccess"
        case .accessWindow: "accessWindow"
        case .completed: "completed"
        }
    }

    private static var traceURL: URL? {
        guard let libraryDirectory = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return libraryDirectory
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("FocumiDebug", isDirectory: true)
            .appendingPathComponent("companion-confirm.jsonl", isDirectory: false)
    }

    private static func value(for key: String, in details: String) -> String? {
        guard let range = details.range(of: "\(key)=") else { return nil }
        let remainder = details[range.upperBound...]
        return remainder.prefix { !$0.isWhitespace }.isEmpty
            ? nil
            : String(remainder.prefix { !$0.isWhitespace })
    }

    private static func boolValue(in details: String) -> Bool? {
        for key in ["result", "changeAllowed", "shouldCommit"] {
            if let value = value(for: key, in: details).flatMap(Bool.init) {
                return value
            }
        }
        return nil
    }

    private static func appendToSandbox(
        eventID: UInt64,
        context: Context,
        guardResult: Bool?,
        errorCategory: String
    ) {
        guard let url = traceURL else { return }
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let record = Record(
                eventID: eventID,
                monotonicMilliseconds: DispatchTime.now().uptimeNanoseconds / 1_000_000,
                selectedPet: context.selectedPet,
                snapshotPet: context.snapshotPet,
                remainingPetChanges: context.remainingPetChanges,
                phase: context.phase,
                guardResult: guardResult,
                presentation: context.presentation,
                errorCategory: errorCategory
            )
            var line = try JSONEncoder().encode(record)
            line.append(0x0A)
            let existingBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if existingBytes + line.count > maximumTraceBytes {
                try? FileManager.default.removeItem(at: url)
            }
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            // Diagnostics must not alter the companion-confirmation behavior.
        }
    }
}
#endif

@MainActor
@Observable
final class FriendMVPModel {
    let capability: P0CapabilityModel

    private(set) var snapshot: FriendMVPSnapshot
    private(set) var preferences: FriendBetaPreferences
    var goalDraft: String
    var durationDraft: TimeInterval
    var petNameDraft = ""
    var selectedReason: AccessReasonKind = .studyResearch
    var customReasonDraft = ""
    private(set) var startGuidance: LocalizedStringResource?
    private(set) var dataRecoveryNeeded = false
    private(set) var notificationPermission: NotificationPermissionState = .notDetermined
    private(set) var focusDeadlineCoordinationIssue = false
    private(set) var betaValidationState: BetaValidationState
    private(set) var betaValidationRecoveryNeeded = false
    private(set) var musicPlaybackState: FocusAudioPlaybackState = .stopped

    private let store: FriendMVPStore
    private let notifications: LocalNotificationClient
    private let focusAudio: FocusAudioClient
    private let focusDeadlineMonitor: FocusDeadlineMonitorClient
    private let focusLiveActivity: FocusLiveActivityClient
    private let betaValidationStore: BetaValidationStore
    private let companionPresentationStore: AppGroupStore?
    private var lastRoutedIntentID: UUID?

    init(
        capability: P0CapabilityModel = P0CapabilityModel(),
        store: FriendMVPStore = FriendMVPStore(),
        notifications: LocalNotificationClient = LocalNotificationClient(),
        focusAudio: FocusAudioClient = FocusAudioClient(),
        focusDeadlineMonitor: FocusDeadlineMonitorClient = FocusDeadlineMonitorClient(),
        focusLiveActivity: FocusLiveActivityClient = FocusLiveActivityClient(),
        betaValidationStore: BetaValidationStore = BetaValidationStore()
    ) {
#if DEBUG
        CompanionConfirmationDebugTrace.resetForLaunch()
#endif
        self.capability = capability
        self.store = store
        self.notifications = notifications
        self.focusAudio = focusAudio
        self.focusDeadlineMonitor = focusDeadlineMonitor
        self.focusLiveActivity = focusLiveActivity
        self.betaValidationStore = betaValidationStore
        companionPresentationStore = try? AppGroupStore()
        let restored: FriendBetaPersistedState
        switch store.loadState() {
        case .loaded(let state):
            restored = state
        case .recoveryRequired:
            restored = .init(snapshot: .fresh(), preferences: .fresh())
            dataRecoveryNeeded = true
        }
        snapshot = restored.snapshot
        preferences = restored.preferences
        switch betaValidationStore.loadState() {
        case .loaded(let state):
            betaValidationState = state
        case .recoveryRequired:
            betaValidationState = .fresh()
            betaValidationRecoveryNeeded = true
        }
        goalDraft = restored.snapshot.goalMode == .freeFocus ? "" : restored.snapshot.goal
        durationDraft = restored.preferences.preferredFocusDuration
        focusAudio.onPlaybackStateChanged = { [weak self] state in
            self?.musicPlaybackState = state
        }
        focusAudio.sync(preferences: restored.preferences, phase: restored.snapshot.phase)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--friend-mvp-preview-data-recovery") {
            dataRecoveryNeeded = true
        }
#endif
        restoreFocusDeadlineCoordinationIfNeeded()
        syncShieldCompanionPresentation()
        focusLiveActivity.sync(snapshot: restored.snapshot)
        if !betaValidationRecoveryNeeded,
           !betaValidationState.events.contains(where: { $0.kind == .firstEntered }) {
            recordBetaEvent(.init(kind: .firstEntered, occurredAt: Date()))
        }
    }

    var petMood: PetMood {
        switch snapshot.phase {
        case .onboarding, .setup: .welcome
        case .focusing, .requestingAccess: .focusing
        case .accessWindow: .waiting
        case .completed: .celebrating
        }
    }

    var canStart: Bool {
        snapshot.pet != nil
            && capability.authorizationState == .approved
            && capability.selectedItemCount > 0
    }

    var needsFreeFocusConfirmation: Bool {
        goalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var relationshipStage: CompanionRelationshipStage {
        .stage(completedSessions: snapshot.completedSessions)
    }

    var liveActivitiesEnabled: Bool {
        focusLiveActivity.activitiesEnabled
    }

    var liveActivityStatus: LocalizedStringResource {
        liveActivitiesEnabled ? "已开启" : "未开启"
    }

    var shouldOfferBetaFeedback: Bool {
        !betaValidationRecoveryNeeded
            && snapshot.completedSessions > 0
            && !betaValidationState.willingnessToPay.isFinal
    }

    var betaReportText: String {
        guard !betaValidationRecoveryNeeded else {
            return String(localized: "Beta measurement recovery is required before a report can be shared.")
        }
        let report = BetaValidationReportBuilder.build(from: betaValidationState)
        guard let data = try? BetaValidationReportBuilder.jsonData(for: report) else {
            return String(localized: "Beta report unavailable")
        }
        return String(decoding: data, as: UTF8.self)
    }

    func refreshNotificationPermission() async {
        notificationPermission = await notifications.authorizationState()
    }

    func retryDataRecovery() {
        guard case .loaded(let restored) = store.loadState() else {
            dataRecoveryNeeded = true
            return
        }
        snapshot = restored.snapshot
        preferences = restored.preferences
        goalDraft = restored.snapshot.goalMode == .freeFocus ? "" : restored.snapshot.goal
        durationDraft = restored.preferences.preferredFocusDuration
        dataRecoveryNeeded = false
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)
        restoreFocusDeadlineCoordinationIfNeeded()
        syncShieldCompanionPresentation()
        focusLiveActivity.sync(snapshot: snapshot)
    }

    func startFreshAfterDataRecovery() {
        focusDeadlineMonitor.cancel()
        store.clearAllLocalData()
        betaValidationStore.clearAllLocalData()
        snapshot = .fresh()
        preferences = .fresh()
        goalDraft = ""
        durationDraft = preferences.preferredFocusDuration
        petNameDraft = ""
        dataRecoveryNeeded = false
        betaValidationState = .fresh()
        betaValidationRecoveryNeeded = false
        recordBetaEvent(.init(kind: .firstEntered, occurredAt: Date()))
        persistCurrentState()
        focusLiveActivity.sync(snapshot: snapshot)
    }

    func clearAllLocalData() {
        focusDeadlineMonitor.cancel()
        focusAudio.sync(preferences: .fresh(), phase: .setup)
        Task { @MainActor [notifications] in
            await notifications.cancelAccessReminders(windowID: nil)
        }
        capability.clearAllLocalData()
        store.clearAllLocalData()
        betaValidationStore.clearAllLocalData()
        snapshot = .fresh()
        preferences = .fresh()
        goalDraft = ""
        durationDraft = preferences.preferredFocusDuration
        petNameDraft = ""
        selectedReason = .studyResearch
        customReasonDraft = ""
        startGuidance = nil
        dataRecoveryNeeded = false
        focusDeadlineCoordinationIssue = false
        betaValidationState = .fresh()
        betaValidationRecoveryNeeded = false
        recordBetaEvent(.init(kind: .firstEntered, occurredAt: Date()))
        persistCurrentState()
        focusLiveActivity.sync(snapshot: snapshot)
    }

    func adopt(_ species: PetSpecies) {
        let previousPhase = snapshot.phase
        let reduction = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .petAdopted(species: species, name: petNameDraft, at: Date())
        )
        apply(reduction)
        if previousPhase == .onboarding, snapshot.phase == .setup {
            recordBetaEvent(.init(kind: .companionAdopted, occurredAt: Date()))
        }
    }

    func requestAuthorization() async {
        recordBetaEvent(.init(kind: .authorizationRequested, occurredAt: Date()))
        await capability.requestAuthorization()
        let authorizationOutcome: BetaValidationAuthorizationOutcome = switch capability.authorizationState {
        case .approved: .approved
        case .denied: .denied
        case .notDetermined: .unavailable
        }
        recordBetaEvent(.authorization(authorizationOutcome, at: Date()))
        startGuidance = capability.authorizationState == .approved
            ? nil
            : "Enable Screen Time permission so your pet can protect the apps you choose."
    }

    func startSession(allowFreeFocus: Bool = false) async {
        capability.observeAuthorization()
        guard capability.authorizationState == .approved else {
            startGuidance = "Enable Screen Time permission before starting."
            return
        }
        guard capability.selectedItemCount > 0 else {
            startGuidance = "Choose at least one distracting app first."
            capability.isPickerPresented = true
            return
        }
        let trimmedGoal = goalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty || allowFreeFocus else {
            startGuidance = "You can add a goal, or choose free focus when you're ready."
            return
        }

        let goalMode: FocusGoalMode = trimmedGoal.isEmpty ? .freeFocus : .specific
        let effectiveGoal = trimmedGoal.isEmpty ? String(localized: "Free focus") : trimmedGoal

        let remindersAvailable = await notifications.requestAuthorizationIfNeeded()
        let reduction = FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .sessionStarted(
                goal: effectiveGoal,
                goalMode: goalMode,
                duration: durationDraft,
                remindersAvailable: remindersAvailable,
                at: Date()
            )
        )
        startGuidance = remindersAvailable
            ? nil
            : "Reminders are off. Return to the app yourself if you request access."
        let previousPhase = snapshot.phase
        apply(reduction)
        if previousPhase == .setup, snapshot.phase == .focusing {
            recordBetaEvent(.focusStarted(
                duration: snapshot.plannedFocusDuration,
                entrySource: .directAppOpen,
                at: Date()
            ))
        }
    }

    func setPreferredDuration(_ duration: TimeInterval) {
        guard FriendBetaPreferences.supportedFocusDurations.contains(duration) else { return }
        durationDraft = duration
        preferences.preferredFocusDuration = duration
        persistCurrentState()
    }

    func setMusicEnabled(_ isEnabled: Bool) {
        preferences.musicEnabled = isEnabled
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)
        persistCurrentState()
    }

    /// Retries a user-requested track without turning a prior playback error
    /// into a claim that audio is already audible.
    func retryMusicPlayback() {
        guard preferences.musicEnabled else { return }
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)
    }

    /// Focumi does not declare background-audio capability. Stop playback while
    /// inactive and reconcile the user's music preference only after return.
    func setAppActive(_ isActive: Bool) {
        focusAudio.setAppActive(isActive)
    }

    func setMusicTrack(_ track: FocusMusicTrack) {
        preferences.selectedMusicTrack = track
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)
        persistCurrentState()
    }

    func setMusicVolume(_ volume: Double) {
        preferences.musicVolume = min(1, max(0, volume))
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)
        persistCurrentState()
    }

    @discardableResult
    func changePet(
        to species: PetSpecies,
        name: String,
        companionConfirmationTraceID: UInt64? = nil
    ) -> Bool {
#if DEBUG
        if let traceID = companionConfirmationTraceID {
            CompanionConfirmationDebugTrace.emit(
                traceID,
                step: "changePet-entry",
                details: "selected=\(CompanionConfirmationDebugTrace.speciesCode(species)) snapshot=\(CompanionConfirmationDebugTrace.speciesCode(snapshot.pet)) remaining=\(preferences.remainingPetChanges) phase=\(CompanionConfirmationDebugTrace.phaseCode(snapshot.phase))"
            )
        }
#endif
        guard snapshot.phase == .setup else {
#if DEBUG
            if let traceID = companionConfirmationTraceID {
                CompanionConfirmationDebugTrace.emit(traceID, step: "changePet-return", details: "result=false reason=phase")
            }
#endif
            return false
        }
        guard let currentPet = snapshot.pet else {
#if DEBUG
            if let traceID = companionConfirmationTraceID {
                CompanionConfirmationDebugTrace.emit(traceID, step: "changePet-return", details: "result=false reason=missingPet")
            }
#endif
            return false
        }
        guard currentPet != species else {
#if DEBUG
            if let traceID = companionConfirmationTraceID {
                CompanionConfirmationDebugTrace.emit(traceID, step: "changePet-return", details: "result=false reason=samePet")
            }
#endif
            return false
        }

        preferences.archivedPetMemory = ArchivedPetMemory(
            species: currentPet,
            name: snapshot.petName,
            completedSessions: snapshot.completedSessions,
            bondPoints: snapshot.bondPoints,
            focusedDuration: preferences.currentPetFocusedDuration,
            archivedAt: Date()
        )
        preferences.currentPetFocusedDuration = 0
        goalDraft = ""

        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .petChanged(species: species, name: name, at: Date())
        ))
#if DEBUG
        if let traceID = companionConfirmationTraceID {
            CompanionConfirmationDebugTrace.emit(
                traceID,
                step: "changePet-return",
                details: "result=true snapshot=\(CompanionConfirmationDebugTrace.speciesCode(snapshot.pet)) remaining=\(preferences.remainingPetChanges) phase=\(CompanionConfirmationDebugTrace.phaseCode(snapshot.phase))"
            )
        }
#endif
        return true
    }

    /// Commits the companion picked after returning from the Setup pact.
    /// It reuses the established Setup mutation and persistence path. Legacy
    /// `remainingPetChanges` remains stored for compatibility but is not a
    /// selection rule.
    @discardableResult
    func confirmSetupCompanionSelection(
        _ species: PetSpecies,
        companionConfirmationTraceID: UInt64? = nil
    ) -> Bool {
#if DEBUG
        if let traceID = companionConfirmationTraceID {
            let changeAllowed = snapshot.phase == .setup
                && snapshot.pet != nil
                && snapshot.pet != species
            CompanionConfirmationDebugTrace.emit(
                traceID,
                step: "confirm-entry",
                details: "selected=\(CompanionConfirmationDebugTrace.speciesCode(species)) snapshot=\(CompanionConfirmationDebugTrace.speciesCode(snapshot.pet)) remaining=\(preferences.remainingPetChanges) phase=\(CompanionConfirmationDebugTrace.phaseCode(snapshot.phase)) shouldCommit=\(snapshot.pet != species) changeAllowed=\(changeAllowed)"
            )
        }
#endif
        guard snapshot.phase == .setup else {
#if DEBUG
            if let traceID = companionConfirmationTraceID {
                CompanionConfirmationDebugTrace.emit(traceID, step: "confirm-return", details: "result=false reason=phase")
            }
#endif
            return false
        }
        guard snapshot.pet != species else {
#if DEBUG
            if let traceID = companionConfirmationTraceID {
                CompanionConfirmationDebugTrace.emit(traceID, step: "confirm-return", details: "result=true reason=currentPet")
            }
#endif
            return true
        }
        let result = changePet(
            to: species,
            name: "",
            companionConfirmationTraceID: companionConfirmationTraceID
        )
#if DEBUG
        if let traceID = companionConfirmationTraceID {
            CompanionConfirmationDebugTrace.emit(traceID, step: "confirm-return", details: "result=\(result)")
        }
#endif
        return result
    }

    func cancelAccessRequest() {
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .accessRequestCancelled(at: Date())
        ))
    }

    func submitAccessRequest() {
        let effectiveReason: AccessReasonKind = customReasonDraft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? selectedReason : .custom
        let previousPhase = snapshot.phase
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .accessRequestSubmitted(reason: effectiveReason, at: Date())
        ))
        if previousPhase == .requestingAccess, snapshot.phase == .accessWindow {
            recordBetaEvent(.init(kind: .accessRequested, occurredAt: Date()))
        }
        customReasonDraft = ""
    }

    func returnToFocus() {
        let previousPhase = snapshot.phase
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .returnToFocusRequested(at: Date())
        ))
        if previousPhase == .accessWindow, snapshot.phase == .focusing {
            recordBetaEvent(.init(kind: .returnedToFocus, occurredAt: Date()))
        }
    }

    func endSession() {
        let previousPhase = snapshot.phase
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .sessionEnded(at: Date())
        ))
        if previousPhase != .setup, snapshot.phase == .setup {
            recordBetaEvent(.init(kind: .focusEndedEarly, occurredAt: Date()))
        }
    }

    func dismissCompletion() {
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .completionDismissed(at: Date())
        ))
    }

#if DEBUG && targetEnvironment(simulator)
    /// Drives a single continuous simulator-only experience recording. This is
    /// deliberately presentation data: it is never persisted and never invokes
    /// Family Controls, deadlines, notifications, Shield, or Live Activity.
    /// It must not be used as evidence that any iOS system surface succeeded.
    var isIntegratedExperienceDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("--friend-mvp-integrated-demo")
    }

    /// Every simulator fixture is visibly marked in the app so captured UI is
    /// never mistaken for an Apple-owned Family Controls or Shield surface.
    var simulatorFixtureStatus: String? {
        guard isIntegratedExperienceDemo else { return nil }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--p0-simulator-authorization=denied") {
            return "模拟器验证状态：App 内权限拒绝分支；不是 Apple 系统授权页面。"
        }
        if arguments.contains("--p0-simulator-selection=0") {
            return "模拟器验证状态：App 内未选择受限 App 分支；不是 Apple 选择器。"
        }
        if arguments.contains("--p0-simulator-relock=failed") {
            return "模拟器验证状态：App 内重新保护失败分支；不是 Apple Shield。"
        }
        if arguments.contains("--p0-simulator-relock=unknown") {
            return "模拟器验证状态：App 内重新保护未知分支；不是 Apple Shield。"
        }
        if arguments.contains("--p0-simulator-natural-completion") {
            return "模拟器验证状态：App 内自然完成单次结算投影；不是系统计时证明。"
        }
        if arguments.contains("--p0-simulator-early-end") {
            return "模拟器验证状态：App 内提前结束未结算投影；不是系统保护状态。"
        }
        if arguments.contains("--p0-simulator-return") {
            return "模拟器验证状态：App 内 Return 后重新保护请求分支；不是 Apple Shield。"
        }
        return "模拟器验证状态：仅验证 App UI / reducer 投影；不是 Apple Shield。"
    }

    /// A stable, one-screen variant of the integration fixture for labelled
    /// simulator screenshots. It uses the same in-memory presentation data as
    /// the continuous demo and never writes a session or asks iOS for access.
    var integratedExperienceDemoStaticPhase: FriendMVPPhase? {
        guard isIntegratedExperienceDemo,
              let rawValue = ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("--friend-mvp-integrated-demo-phase=") })?
                .split(separator: "=", maxSplits: 1)
                .last
        else { return nil }

        return FriendMVPPhase(rawValue: String(rawValue))
    }

    /// A non-persistent Return-surface fixture for simulator registration QA.
    /// It is deliberately separate from the session reducer and must never be
    /// used as evidence that a temporary-access window exists on iOS.
    var isReturnSignaturePreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--friend-mvp-return-signature-preview")
    }

    /// A short, non-persistent fixture for recording the app-owned opening
    /// moment. It uses the real setup root view but never requests system
    /// permission, changes a session, or writes a completion.
    var isOpeningMomentPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--friend-mvp-opening-preview")
    }

    private var fixtureSpecies: PetSpecies {
        ProcessInfo.processInfo.arguments.contains("--friend-mvp-preview-max") ? .dog : .cat
    }

    private var fixturePetName: String {
        fixtureSpecies == .cat ? "Milo" : "Max"
    }

    /// Screenshot-only duration selection for the existing simulator fixture.
    /// The guard retains the app's ordinary 30-minute setup projection when a
    /// supplied value is unsupported, and this declaration is compiled only
    /// for DEBUG simulator builds.
    private var fixturePlannedFocusDuration: TimeInterval {
        guard let rawMinutes = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--friend-mvp-duration-reaction-minutes=") })?
            .split(separator: "=", maxSplits: 1)
            .last,
              let minutes = TimeInterval(rawMinutes),
              FriendBetaPreferences.supportedFocusDurations.contains(minutes * 60)
        else { return 30 * 60 }
        return minutes * 60
    }

    func presentIntegratedExperienceDemo(phase: FriendMVPPhase, at now: Date = Date()) {
        guard isIntegratedExperienceDemo || isReturnSignaturePreview || isOpeningMomentPreview else { return }

        var demo = FriendMVPSnapshot.fresh(now: now)
        demo.pet = fixtureSpecies
        demo.petName = fixturePetName
        demo.phase = phase
        demo.goal = String(localized: "Finish chapter three")
        demo.goalMode = .specific
        demo.plannedFocusDuration = fixturePlannedFocusDuration
        demo.remainingFocusDuration = 24 * 60
        demo.completedSessions = 3
        demo.bondPoints = 30

        switch phase {
        case .onboarding, .setup:
            break
        case .focusing, .requestingAccess:
            demo.focusDeadline = now.addingTimeInterval(24 * 60)
        case .accessWindow:
            demo.accessWindowID = UUID()
            demo.accessStartedAt = now.addingTimeInterval(-8 * 60)
            demo.accessDeadline = now.addingTimeInterval(52 * 60)
            demo.accessRequestCount = 1
            demo.latestReason = .studyResearch
        case .completed:
            demo.remainingFocusDuration = 0
        }

        if ProcessInfo.processInfo.arguments.contains("--p0-simulator-natural-completion") {
            demo.phase = .completed
            demo.remainingFocusDuration = 0
            demo.completedSessions = 4
        } else if ProcessInfo.processInfo.arguments.contains("--p0-simulator-early-end") {
            demo.phase = .setup
            demo.goal = ""
            demo.goalMode = .freeFocus
            demo.completedSessions = 3
        }

        snapshot = demo
        goalDraft = demo.goal
        durationDraft = demo.plannedFocusDuration
        petNameDraft = demo.petName
        selectedReason = .studyResearch
        customReasonDraft = ""
        startGuidance = nil
    }
#endif

    func reconcile(at now: Date = Date()) {
#if DEBUG && targetEnvironment(simulator)
        // The recording fixture never reconciles fake presentation snapshots
        // into effects or persisted business state.
        guard !isIntegratedExperienceDemo, !isReturnSignaturePreview, !isOpeningMomentPreview else { return }
#endif
        capability.reconcileAfterActivation()
        routeLatestShieldIntent(at: now)
        let previousPhase = snapshot.phase
        apply(FriendMVPReducer.reduce(snapshot: snapshot, event: .reconcile(at: now)))
        if previousPhase == .focusing, snapshot.phase == .completed {
            recordBetaEvent(.focusCompleted(duration: snapshot.plannedFocusDuration, at: now))
        } else if previousPhase == .accessWindow, snapshot.phase == .setup {
            recordBetaEvent(.init(kind: .accessTimedOut, occurredAt: now))
        }
    }

    func openBetaFeedback() {
        guard !betaValidationState.willingnessToPay.isFinal else { return }
        recordBetaEvent(.init(kind: .feedbackFlowOpened, occurredAt: Date()))
    }

    func submitBetaFeedback(
        productUnderstanding: BetaValidationProductUnderstanding,
        ownershipDesire: BetaValidationOwnershipDesire,
        purchaseDriver: BetaValidationPurchaseDriver,
        purchaseIntent: BetaValidationPurchaseIntent,
        selectedPrice: BetaValidationPriceBucket?,
        customPriceBucket: BetaValidationPriceBucket?
    ) {
        guard !betaValidationState.willingnessToPay.isFinal else { return }
        let now = Date()
        betaValidationState.append(.init(kind: .feedbackConfirmedByUser, occurredAt: now))
        betaValidationState.recordWillingnessToPay(.init(
            productUnderstanding: productUnderstanding,
            ownershipDesire: ownershipDesire,
            purchaseDriver: purchaseDriver,
            intent: purchaseIntent,
            selectedPrice: selectedPrice,
            customPriceBucket: customPriceBucket,
            answeredAt: now
        ))
        persistBetaValidationState()
    }

    func dismissBetaFeedback() {
        betaValidationState.dismissWillingnessToPay(at: Date())
        persistBetaValidationState()
    }

    func routeLatestShieldIntent(at now: Date = Date()) {
        guard let intentID = capability.latestIntentRecordID,
              intentID != lastRoutedIntentID else {
            return
        }
        lastRoutedIntentID = intentID
        apply(FriendMVPReducer.reduce(
            snapshot: snapshot,
            event: .shieldRequestReceived(at: now)
        ))
    }

    func remainingFocusTime(at now: Date) -> TimeInterval {
        guard snapshot.phase == .focusing, let deadline = snapshot.focusDeadline else {
            return max(0, snapshot.remainingFocusDuration)
        }
        return max(0, deadline.timeIntervalSince(now))
    }

    func remainingAccessTime(at now: Date) -> TimeInterval {
        guard let deadline = snapshot.accessDeadline else {
            return 0
        }
        return max(0, deadline.timeIntervalSince(now))
    }

    private func apply(_ reduction: FriendMVPReduction) {
        guard !dataRecoveryNeeded else { return }
        let previousPhase = snapshot.phase
        snapshot = reduction.snapshot
        let isReturningToFocus = previousPhase == .accessWindow && snapshot.phase == .focusing

        if previousPhase != .completed, snapshot.phase == .completed {
            preferences.currentPetFocusedDuration += snapshot.plannedFocusDuration
        }
        focusAudio.sync(preferences: preferences, phase: snapshot.phase)

        for effect in reduction.effects {
            switch effect {
            case .applyProtection:
                capability.requestProtection()

            case .clearProtection:
                capability.requestProtectionRemoval()

            case .reapplyProtection:
                capability.requestProtectionRestoration()

            case .scheduleFocusDeadline(let monitorID, let deadline):
                do {
                    try focusDeadlineMonitor.schedule(monitorID: monitorID, deadline: deadline)
                    focusDeadlineCoordinationIssue = false
                } catch {
                    focusDeadlineCoordinationIssue = true
                }

            case .cancelFocusDeadline:
                focusDeadlineMonitor.cancel()
                focusDeadlineCoordinationIssue = false

            case .scheduleAccessReminders(let windowID, let startedAt):
                Task { @MainActor [notifications, snapshot] in
                    await notifications.scheduleAccessReminders(
                        windowID: windowID,
                        petName: CompanionPresentation.displayName(
                            for: snapshot.pet,
                            storedName: snapshot.petName
                        ),
                        startedAt: startedAt
                    )
                }

            case .cancelAccessReminders(let windowID):
                Task { @MainActor [notifications] in
                    await notifications.cancelAccessReminders(windowID: windowID)
                }

            case .syncLiveActivity:
                focusLiveActivity.sync(
                    snapshot: snapshot,
                    presentingReturn: isReturningToFocus
                )

            case .persist:
                persistCurrentState()
            }
        }
    }

    private func persistCurrentState() {
        guard !dataRecoveryNeeded else { return }
        store.save(.init(snapshot: snapshot, preferences: preferences))
        syncShieldCompanionPresentation()
    }

    private func syncShieldCompanionPresentation() {
        guard let companionPresentationStore else { return }
        guard let pet = snapshot.pet else {
            companionPresentationStore.removeValue(forKey: AppGroupKeys.shieldCompanionSpecies)
            return
        }
        try? companionPresentationStore.write(
            pet.rawValue,
            forKey: AppGroupKeys.shieldCompanionSpecies
        )
    }

    private func recordBetaEvent(_ event: BetaValidationEvent) {
        guard !betaValidationRecoveryNeeded else { return }
        betaValidationState.append(event)
        persistBetaValidationState()
    }

    private func persistBetaValidationState() {
        guard !betaValidationRecoveryNeeded else { return }
        betaValidationStore.save(betaValidationState)
    }

    private func restoreFocusDeadlineCoordinationIfNeeded() {
        guard !dataRecoveryNeeded,
              snapshot.phase == .focusing,
              let deadline = snapshot.focusDeadline,
              deadline > Date() else {
            return
        }
        let monitorID = snapshot.focusMonitorID ?? UUID()
        if snapshot.focusMonitorID == nil {
            snapshot.focusMonitorID = monitorID
            persistCurrentState()
        }
        do {
            try focusDeadlineMonitor.schedule(monitorID: monitorID, deadline: deadline)
            focusDeadlineCoordinationIssue = false
        } catch {
            focusDeadlineCoordinationIssue = true
        }
    }
}

@MainActor
final class FocusDeadlineMonitorClient {
    static let activityName = "disciplined-pet.focus-deadline"
    static let minimumScheduleDuration: TimeInterval = 15 * 60

    private let center = DeviceActivityCenter()
    private let appGroupStore: AppGroupStore?

    init(appGroupStore: AppGroupStore? = try? AppGroupStore()) {
        self.appGroupStore = appGroupStore
    }

    func schedule(monitorID: UUID, deadline: Date, now: Date = Date()) throws {
        guard let scheduleInterval = Self.scheduleInterval(deadline: deadline, now: now) else {
            cancel()
            return
        }

        cancel()
        let activity = DeviceActivityName(Self.activityName)
        let calendar = Calendar.autoupdatingCurrent
        var intervalStart = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: scheduleInterval.start
        )
        var intervalEnd = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: deadline
        )
        intervalStart.calendar = calendar
        intervalStart.timeZone = calendar.timeZone
        intervalEnd.calendar = calendar
        intervalEnd.timeZone = calendar.timeZone

        guard let appGroupStore else {
            throw FocusDeadlineMonitorError.appGroupUnavailable
        }
        let context = FocusDeadlineMonitorContext(
            monitorID: monitorID,
            activityName: Self.activityName,
            deadline: deadline
        )
        try appGroupStore.write(context, forKey: AppGroupKeys.focusDeadlineMonitor)

        do {
            try center.startMonitoring(
                activity,
                during: DeviceActivitySchedule(
                    intervalStart: intervalStart,
                    intervalEnd: intervalEnd,
                    repeats: false
                )
            )
        } catch {
            appGroupStore.removeValue(forKey: AppGroupKeys.focusDeadlineMonitor)
            throw error
        }
    }

    func cancel() {
        appGroupStore?.removeValue(forKey: AppGroupKeys.focusDeadlineMonitor)
        center.stopMonitoring([DeviceActivityName(Self.activityName)])
    }

    static func scheduleInterval(deadline: Date, now: Date) -> DateInterval? {
        guard deadline > now else { return nil }
        return DateInterval(
            start: min(now, deadline.addingTimeInterval(-minimumScheduleDuration)),
            end: deadline
        )
    }
}

private enum FocusDeadlineMonitorError: Error {
    case appGroupUnavailable
}

nonisolated enum FocusAudioFailure: Error, Equatable, Sendable {
    case assetUnavailable
    case playerInitialization
    case sessionActivation
    case sessionDeactivation
    case playbackStart
}

nonisolated enum FocusAudioPlaybackState: Equatable, Sendable {
    case stopped
    case preparing
    case playing
    case interrupted
    case failed(FocusAudioFailure)
}

/// A presentation-only audio route. It deliberately has no relationship to
/// focus protection, timer completion, or any system-owned truth.
nonisolated enum FocumiAudioProgram: Equatable, Sendable {
    case stopped
    case homeAmbience
    case focusSoundscape(FocusMusicTrack)
    case completionCue
}

nonisolated enum FocumiAudioRouting {
    static func program(
        phase: FriendMVPPhase,
        preferences: FriendBetaPreferences,
        appIsActive: Bool,
        presentationIsReady: Bool,
        completionCueHasPlayed: Bool
    ) -> FocumiAudioProgram {
        guard preferences.musicEnabled, appIsActive, presentationIsReady else {
            return .stopped
        }

        switch phase {
        case .onboarding, .setup:
            return .homeAmbience
        case .focusing, .requestingAccess, .accessWindow:
            return .focusSoundscape(preferences.selectedMusicTrack)
        case .completed:
            return completionCueHasPlayed ? .homeAmbience : .completionCue
        }
    }

    static func targetVolume(
        for program: FocumiAudioProgram,
        userVolume: Double
    ) -> Float {
        let clampedUserVolume = min(1, max(0, userVolume))
        switch program {
        case .stopped:
            return 0
        case .homeAmbience:
            return Float(clampedUserVolume * 0.25)
        case .focusSoundscape:
            return Float(clampedUserVolume * 0.38)
        case .completionCue:
            return Float(clampedUserVolume * 0.32)
        }
    }

    static func assetName(for program: FocumiAudioProgram) -> String? {
        switch program {
        case .stopped:
            nil
        case .homeAmbience:
            "FirstLightSlow"
        case .focusSoundscape(let track):
            switch track {
            case .firstLight: "FirstLightSlow"
            case .budding: "BuddingSlow"
            case .deepBlue: "DeepBlueSlow"
            }
        case .completionCue:
            "BuddingSlow"
        }
    }

    static func loopCount(for program: FocumiAudioProgram) -> Int {
        switch program {
        case .homeAmbience, .focusSoundscape:
            -1
        case .completionCue:
            0
        case .stopped:
            0
        }
    }

    static func hasVerifiedPlayback(
        isPlaying: Bool,
        startTime: TimeInterval,
        currentTime: TimeInterval,
        volume: Float
    ) -> Bool {
        isPlaying && currentTime > startTime + 0.05 && volume > 0
    }
}

@MainActor
final class FocusAudioClient {
    private var primaryPlayer: AVAudioPlayer?
    private var secondaryPlayer: AVAudioPlayer?
    private var activeProgram: FocumiAudioProgram = .stopped
    private var desiredProgram: FocumiAudioProgram = .stopped
    private var appIsActive = true
    private var presentationIsReady = false
    private var completionCueHasPlayed = false
    private var latestPreferences: FriendBetaPreferences?
    private var latestPhase: FriendMVPPhase?
    private let dataAssetProvider: (String) -> Data?
    private let playerFactory: (Data) throws -> AVAudioPlayer
    // NotificationCenter observer tokens are Objective-C values. They are only
    // created, consumed, and removed by this coordinator; the explicit unsafe
    // boundary lets Swift 6's nonisolated deinit release them without widening
    // any audio state off the main actor.
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?
    nonisolated(unsafe) private var routeChangeObserver: NSObjectProtocol?
    private var transitionTask: Task<Void, Never>?
    private var completionCueTask: Task<Void, Never>?
    private var playbackVerificationTask: Task<Void, Never>?
    private var transitionGeneration = 0
    private let audioLogger = Logger(subsystem: "com.cczij.disciplinedpet", category: "FocusAudio")

    private func emitDeviceDiagnostic(_ message: String) {
        #if DEBUG
        print("FOCUMI_AUDIO \(message)")
        #endif
    }

    private let crossfadeDuration: TimeInterval = 0.9
    private let completionCueDuration: TimeInterval = 1.1

    private(set) var playbackState: FocusAudioPlaybackState = .stopped {
        didSet {
            guard oldValue != playbackState else { return }
            onPlaybackStateChanged?(playbackState)
        }
    }
    var onPlaybackStateChanged: ((FocusAudioPlaybackState) -> Void)?

    init(
        dataAssetProvider: @escaping (String) -> Data? = { name in
            NSDataAsset(name: name)?.data
        },
        playerFactory: @escaping (Data) throws -> AVAudioPlayer = { data in
            try AVAudioPlayer(data: data)
        }
    ) {
        self.dataAssetProvider = dataAssetProvider
        self.playerFactory = playerFactory
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                self?.handleInterruption(rawType: rawType, rawOptions: rawOptions)
            }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncLatestRoute()
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func sync(preferences: FriendBetaPreferences, phase: FriendMVPPhase) {
        latestPreferences = preferences
        latestPhase = phase
        if phase != .completed {
            completionCueHasPlayed = false
        }
        transition(to: FocumiAudioRouting.program(
            phase: phase,
            preferences: preferences,
            appIsActive: appIsActive,
            presentationIsReady: presentationIsReady,
            completionCueHasPlayed: completionCueHasPlayed
        ))
    }

    func setAppActive(_ isActive: Bool) {
        appIsActive = isActive
        presentationIsReady = presentationIsReady || isActive
        guard let latestPreferences, let latestPhase else { return }
        sync(preferences: latestPreferences, phase: latestPhase)
    }

    private func transition(to nextProgram: FocumiAudioProgram) {
        guard desiredProgram != nextProgram || primaryPlayer?.isPlaying != true else {
            return
        }

        desiredProgram = nextProgram
        transitionGeneration &+= 1
        let generation = transitionGeneration
        transitionTask?.cancel()
        completionCueTask?.cancel()
        playbackVerificationTask?.cancel()

        guard nextProgram != .stopped else {
            stopAndDeactivate()
            return
        }

        playbackState = .preparing
        Task { [weak self] in
            let result = await Self.configureAudioSession(active: true)
            guard let self, self.transitionGeneration == generation,
                  self.desiredProgram == nextProgram else { return }
            guard case .success = result else {
                self.playbackState = .failed(.sessionActivation)
                self.audioLogger.error("Audio session activation failed")
                return
            }
            let route = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType.rawValue ?? "none"
            self.audioLogger.notice("Audio session active category=ambient route=\(route, privacy: .public)")
            self.emitDeviceDiagnostic("session=active category=ambient route=\(route)")
            self.startTransition(to: nextProgram, generation: generation)
        }
    }

    private func startTransition(to nextProgram: FocumiAudioProgram, generation: Int) {
        if nextProgram == activeProgram,
           let primaryPlayer {
            let targetVolume = FocumiAudioRouting.targetVolume(
                for: nextProgram,
                userVolume: latestPreferences?.musicVolume ?? 0
            )
            primaryPlayer.volume = targetVolume
            let startTime = primaryPlayer.currentTime
            guard primaryPlayer.play() else {
                playbackState = .failed(.playbackStart)
                audioLogger.error("Audio player rejected resume")
                return
            }
            verifyPlayback(
                primaryPlayer,
                assetName: FocumiAudioRouting.assetName(for: nextProgram) ?? "unknown",
                startTime: startTime,
                generation: generation
            )
            return
        }

        guard let next = makePlayer(for: nextProgram) else { return }
        let nextPlayer = next.player
        let targetVolume = FocumiAudioRouting.targetVolume(
            for: nextProgram,
            userVolume: latestPreferences?.musicVolume ?? 0
        )
        let previousPlayer = primaryPlayer

        nextPlayer.volume = previousPlayer?.isPlaying == true ? 0 : targetVolume
        let startTime = nextPlayer.currentTime
        guard nextPlayer.play() else {
            playbackState = .failed(.playbackStart)
            audioLogger.error("Audio player rejected start asset=\(next.assetName, privacy: .public)")
            return
        }

        activeProgram = nextProgram
        primaryPlayer = nextPlayer
        verifyPlayback(
            nextPlayer,
            assetName: next.assetName,
            startTime: startTime,
            generation: generation
        )

        guard let previousPlayer, previousPlayer.isPlaying else {
            scheduleCompletionHomeIfNeeded(for: nextProgram, generation: generation)
            return
        }

        secondaryPlayer?.stop()
        secondaryPlayer = previousPlayer
        crossfade(
            from: previousPlayer,
            to: nextPlayer,
            targetVolume: targetVolume,
            generation: generation,
            nextProgram: nextProgram
        )
    }

    private func makePlayer(for program: FocumiAudioProgram) -> (player: AVAudioPlayer, assetName: String)? {
        guard let assetName = FocumiAudioRouting.assetName(for: program) else { return nil }
        guard let data = dataAssetProvider(assetName) else {
            playbackState = .failed(.assetUnavailable)
            audioLogger.error("Audio asset unavailable asset=\(assetName, privacy: .public)")
            return nil
        }

        let nextPlayer: AVAudioPlayer
        do {
            nextPlayer = try playerFactory(data)
        } catch {
            playbackState = .failed(.playerInitialization)
            audioLogger.error("Audio player initialization failed asset=\(assetName, privacy: .public)")
            return nil
        }

        nextPlayer.numberOfLoops = FocumiAudioRouting.loopCount(for: program)
        nextPlayer.prepareToPlay()
        audioLogger.notice("Audio player prepared asset=\(assetName, privacy: .public) duration=\(nextPlayer.duration, privacy: .public)")
        emitDeviceDiagnostic("asset=\(assetName) prepared duration=\(nextPlayer.duration)")
        return (nextPlayer, assetName)
    }

    private func verifyPlayback(
        _ player: AVAudioPlayer,
        assetName: String,
        startTime: TimeInterval,
        generation: Int
    ) {
        playbackVerificationTask?.cancel()
        playbackVerificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled,
                  self.transitionGeneration == generation,
                  self.primaryPlayer === player else { return }

            guard FocumiAudioRouting.hasVerifiedPlayback(
                isPlaying: player.isPlaying,
                startTime: startTime,
                currentTime: player.currentTime,
                volume: player.volume
            ) else {
                self.playbackState = .failed(.playbackStart)
                self.audioLogger.error("Audio playback verification failed asset=\(assetName, privacy: .public) playing=\(player.isPlaying, privacy: .public) time=\(player.currentTime, privacy: .public) volume=\(player.volume, privacy: .public)")
                self.emitDeviceDiagnostic("playback=failed asset=\(assetName) playing=\(player.isPlaying) time=\(player.currentTime) volume=\(player.volume)")
                return
            }

            self.playbackState = .playing
            self.audioLogger.notice("Audio playback verified asset=\(assetName, privacy: .public) time=\(player.currentTime, privacy: .public) volume=\(player.volume, privacy: .public)")
            self.emitDeviceDiagnostic("playback=verified asset=\(assetName) time=\(player.currentTime) volume=\(player.volume)")
        }
    }

    private func crossfade(
        from previousPlayer: AVAudioPlayer,
        to nextPlayer: AVAudioPlayer,
        targetVolume: Float,
        generation: Int,
        nextProgram: FocumiAudioProgram
    ) {
        transitionTask = Task { @MainActor [weak self] in
            let steps = 9
            for step in 1...steps {
                guard let self, !Task.isCancelled,
                      self.transitionGeneration == generation,
                      self.primaryPlayer === nextPlayer else { return }
                let progress = Float(step) / Float(steps)
                previousPlayer.volume = targetVolume * (1 - progress)
                nextPlayer.volume = targetVolume * progress
                try? await Task.sleep(for: .seconds(self.crossfadeDuration / Double(steps)))
            }
            guard let self, !Task.isCancelled,
                  self.transitionGeneration == generation,
                  self.primaryPlayer === nextPlayer else { return }
            previousPlayer.stop()
            self.secondaryPlayer = nil
            self.scheduleCompletionHomeIfNeeded(for: nextProgram, generation: generation)
        }
    }

    private func scheduleCompletionHomeIfNeeded(
        for program: FocumiAudioProgram,
        generation: Int
    ) {
        guard program == .completionCue else { return }
        completionCueHasPlayed = true
        completionCueTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.completionCueDuration))
            guard !Task.isCancelled,
                  self.transitionGeneration == generation,
                  self.desiredProgram == .completionCue,
                  let latestPreferences,
                  latestPreferences.musicEnabled,
                  self.appIsActive,
                  self.presentationIsReady else { return }
            self.transition(to: .homeAmbience)
        }
    }

    private func stopAndDeactivate() {
        primaryPlayer?.stop()
        secondaryPlayer?.stop()
        primaryPlayer = nil
        secondaryPlayer = nil
        playbackVerificationTask?.cancel()
        activeProgram = .stopped
        playbackState = .stopped
        Task { [weak self] in
            let result = await Self.configureAudioSession(active: false)
            guard let self, self.desiredProgram == .stopped else { return }
            if case .failure = result {
                self.playbackState = .failed(.sessionDeactivation)
            }
        }
    }

    private func handleInterruption(rawType: UInt?, rawOptions: UInt) {
        guard let rawType,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch interruptionType {
        case .began:
            primaryPlayer?.pause()
            secondaryPlayer?.pause()
            playbackState = .interrupted
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume), let latestPreferences, let latestPhase {
                sync(preferences: latestPreferences, phase: latestPhase)
            }
        @unknown default:
            break
        }
    }

    private func syncLatestRoute() {
        guard let latestPreferences, let latestPhase else { return }
        sync(preferences: latestPreferences, phase: latestPhase)
    }

    private nonisolated static func configureAudioSession(active: Bool) async -> Result<Void, FocusAudioFailure> {
        await Task { @concurrent in
            let session = AVAudioSession.sharedInstance()
            do {
                if active {
                    try session.setCategory(
                        .ambient,
                        mode: .default,
                        options: [.mixWithOthers]
                    )
                    try session.setActive(true)
                } else {
                    try session.setActive(
                        false,
                        options: [.notifyOthersOnDeactivation]
                    )
                }
                return .success(())
            } catch {
                return .failure(active ? .sessionActivation : .sessionDeactivation)
            }
        }.value
    }
}

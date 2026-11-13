import FamilyControls
import SwiftUI

struct P0CapabilityView: View {
    let model: P0CapabilityModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                P0ScopeSection()
                P0AuthorizationSection(
                    state: model.authorizationState,
                    requestAuthorization: {
                        Task { await model.requestAuthorization() }
                    },
                    revokeAuthorization: {
                        Task { await model.revokeAuthorization() }
                    }
                )
                P0SelectionSection(
                    selectedItemCount: model.selectedItemCount,
                    openPicker: { model.isPickerPresented = true }
                )
                P0CommandSection(
                    canApply: model.authorizationState == .approved && model.selectedItemCount > 0,
                    requestProtection: model.requestProtection,
                    requestRemoval: model.requestProtectionRemoval,
                    requestRestoration: model.requestProtectionRestoration
                )
                P0EvidenceSection(
                    message: model.message,
                    generation: model.state.generation,
                    commandKind: model.state.lastCommandReceipt?.kind,
                    intentContext: model.latestIntentContext,
                    errorCode: model.state.latestErrorCode
                )
            }
            .navigationTitle("Technical verification")
        }
        .familyActivityPicker(
            isPresented: $model.isPickerPresented,
            selection: $model.selection
        )
        .onChange(of: model.selection) {
            model.selectionChanged()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                model.reconcileAfterActivation()
            }
        }
        .task {
            model.reconcileAfterActivation()
        }
    }
}

private struct P0ScopeSection: View {
    var body: some View {
        Section {
            Label("Apple Screen Time capability spike", systemImage: "shield.lefthalf.filled")
                .font(.headline)
            Text("P0 only verifies Apple capabilities. It does not prove the product or pet system.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct P0AuthorizationSection: View {
    let state: P0AuthorizationState
    let requestAuthorization: () -> Void
    let revokeAuthorization: () -> Void
    @State private var isRevokeConfirmationPresented = false

    var body: some View {
        Section("Authorization") {
            LabeledContent("Status") {
                Text(statusText)
            }
            Button("Request Family Controls authorization", action: requestAuthorization)
            Button("Temporarily revoke test authorization", role: .destructive) {
                isRevokeConfirmationPresented = true
            }
            .disabled(state != .approved)
        }
        .confirmationDialog(
            "Temporarily revoke test authorization?",
            isPresented: $isRevokeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Revoke and continue verification", role: .destructive, action: revokeAuthorization)
            Button("Keep authorization", role: .cancel) {}
        } message: {
            Text("This only verifies authorization recovery. Your app selection stays saved, and you can authorize again when ready.")
        }
    }

    private var statusText: LocalizedStringResource {
        switch state {
        case .notDetermined: "Not determined"
        case .denied: "Permission needed"
        case .approved: "Approved"
        }
    }
}

private struct P0SelectionSection: View {
    let selectedItemCount: Int
    let openPicker: () -> Void

    var body: some View {
        Section("Selection") {
            LabeledContent("Selected items", value: selectedItemCount, format: .number)
            Button("Choose distracting apps", action: openPicker)
        }
    }
}

private struct P0CommandSection: View {
    let canApply: Bool
    let requestProtection: () -> Void
    let requestRemoval: () -> Void
    let requestRestoration: () -> Void

    var body: some View {
        Section("Local Shield requests") {
            Button("Request protection", action: requestProtection)
                .disabled(!canApply)
            Button("Request protection removal", action: requestRemoval)
            Button("Request protection restoration", action: requestRestoration)
                .disabled(!canApply)
        }
    }
}

private struct P0EvidenceSection: View {
    let message: P0UserMessage
    let generation: Int
    let commandKind: ShieldCommandKind?
    let intentContext: ShieldIntentContext?
    let errorCode: String?

    var body: some View {
        Section("Local evidence") {
            Text(messageText)
                .foregroundStyle(message == .recoveryNeeded ? .orange : .secondary)
            LabeledContent("Generation", value: generation, format: .number)
            if let commandKind {
                LabeledContent("Last command", value: commandKind.rawValue)
            }
            if let intentContext {
                LabeledContent("Shield context", value: intentContext.rawValue)
                Text("Shield request received from the system screen.")
            }
            if let errorCode {
                LabeledContent("Diagnostic code", value: errorCode)
            }
        }
    }

    private var messageText: LocalizedStringResource {
        switch message {
        case .ready: "Ready for local capability checks."
        case .authorizationApproved: "Authorization is available for the next check."
        case .authorizationNeeded: "Permission is not available. You can try again when ready."
        case .authorizationRevoked: "Test authorization is paused. Your selection is safe, and you can authorize again when ready."
        case .selectionSaved: "Selection saved locally."
        case .localCommandDispatched: "Local request dispatched. Verify the real Shield on iPhone."
        case .shieldRequestReceived: "Shield request received from the system screen."
        case .recoveryNeeded: "The local check needs attention before continuing."
        }
    }
}

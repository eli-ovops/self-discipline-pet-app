import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ShieldProtectionClient {
    private let managedStore = ManagedSettingsStore(named: .init("disciplined-pet-p0"))

    func dispatch(
        kind: ShieldCommandKind,
        selection: FamilyActivitySelection,
        sessionID: UUID,
        generation: Int,
        requestedAt: Date
    ) -> ShieldCommandReceipt {
        switch kind {
        case .apply, .reapply:
            managedStore.shield.applications = selection.applicationTokens.isEmpty
                ? nil
                : selection.applicationTokens
            managedStore.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens)
            managedStore.shield.webDomains = selection.webDomainTokens.isEmpty
                ? nil
                : selection.webDomainTokens
            managedStore.shield.webDomainCategories = nil

        case .clear:
            managedStore.shield.applications = nil
            managedStore.shield.applicationCategories = nil
            managedStore.shield.webDomains = nil
            managedStore.shield.webDomainCategories = nil
        }

        return ShieldCommandReceipt(
            commandID: UUID(),
            sessionID: sessionID,
            generation: generation,
            kind: kind,
            requestedAt: requestedAt,
            localDispatch: .invoked,
            preconditionErrorCode: nil
        )
    }
}

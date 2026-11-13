import Foundation
import ManagedSettings

final class DisciplinedPetShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, context: .application, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, context: .category, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, context: .webDomain, completionHandler: completionHandler)
    }

    private func handle(
        action: ShieldAction,
        context: ShieldIntentContext,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)

        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            guard persistIntent(context: context) else {
                completionHandler(.defer)
                return
            }
            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                // iOS 17–26.4 cannot open the containing app from a Shield
                // Action. Leave the shield unchanged; the TTL-bound intent can
                // only be consumed if the user opens Focumi independently.
                completionHandler(.none)
            }

        @unknown default:
            completionHandler(.defer)
        }
    }

    private func persistIntent(context: ShieldIntentContext) -> Bool {
        do {
            let store = try AppGroupStore()
            guard let snapshot = try store.read(
                P0SessionSnapshot.self,
                forKey: AppGroupKeys.sessionSnapshot
            ) else {
                return false
            }

            let now = Date()
            let envelope = SharedEnvelope(
                sessionID: snapshot.sessionID,
                generation: snapshot.generation,
                createdAt: now,
                expiresAt: now.addingTimeInterval(60),
                payload: PendingShieldIntent(context: context)
            )
            try store.write(envelope, forKey: AppGroupKeys.pendingShieldIntent)
            return true
        } catch {
            return false
        }
    }
}

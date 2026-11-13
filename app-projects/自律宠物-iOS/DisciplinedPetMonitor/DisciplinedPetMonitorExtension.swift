import DeviceActivity
import Foundation
import ManagedSettings

final class DisciplinedPetMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        persist(kind: .intervalStarted, activity: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearFocusProtectionIfNeeded(activity: activity, now: Date())
        persist(kind: .intervalEnded, activity: activity)
    }

    private func clearFocusProtectionIfNeeded(activity: DeviceActivityName, now: Date) {
        guard activity.rawValue == "disciplined-pet.focus-deadline" else { return }
        do {
            let appGroupStore = try AppGroupStore()
            guard let context = try appGroupStore.read(
                FocusDeadlineMonitorContext.self,
                forKey: AppGroupKeys.focusDeadlineMonitor
            ),
                context.activityName == activity.rawValue,
                now >= context.deadline else {
                return
            }

            let managedStore = ManagedSettingsStore(named: .init("disciplined-pet-p0"))
            managedStore.shield.applications = nil
            managedStore.shield.applicationCategories = nil
            managedStore.shield.webDomains = nil
            managedStore.shield.webDomainCategories = nil
            appGroupStore.removeValue(forKey: AppGroupKeys.focusDeadlineMonitor)
        } catch {
            // The main app remains the authority and reconciles the saved deadline on activation.
        }
    }

    private func persist(kind: MonitorEventKind, activity: DeviceActivityName) {
        do {
            let store = try AppGroupStore()
            let previous = try store.read(MonitorEvent.self, forKey: AppGroupKeys.monitorEvent)
            let event = MonitorEvent(
                sequence: (previous?.sequence ?? 0) + 1,
                kind: kind,
                activityName: activity.rawValue,
                createdAt: Date()
            )
            try store.write(event, forKey: AppGroupKeys.monitorEvent)
        } catch {
            // P0-C records storage failures through the main app reconciliation path.
        }
    }
}

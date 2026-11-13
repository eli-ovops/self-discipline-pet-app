import Foundation
import UserNotifications

nonisolated enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case enabled
    case disabled
}

@MainActor
final class LocalNotificationClient {
    private let center = UNUserNotificationCenter.current()

    func authorizationState() async -> NotificationPermissionState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .disabled
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduleAccessReminders(
        windowID: UUID,
        petName: String,
        startedAt: Date
    ) async {
        await cancelAccessReminders(windowID: windowID)

        let reminders: [(minutes: Int, body: String)] = [
            (
                10,
                String(
                    localized: "10 minutes have passed. Ready to return with \(petName)?",
                    comment: "Access reminder. The variable is the pet's name."
                )
            ),
            (
                30,
                String(
                    localized: "\(petName) still remembers your goal. When you're ready, let's continue.",
                    comment: "Access reminder. The variable is the pet's name."
                )
            ),
            (
                60,
                String(
                    localized: "Let's pause here for now. Your goal is still here for next time.",
                    comment: "Access window expiry reminder with encouraging language."
                )
            ),
        ]

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Disciplined Pet")
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [
                "accessWindowID": windowID.uuidString,
                "startedAt": startedAt.timeIntervalSince1970,
            ]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(reminder.minutes * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: identifier(windowID: windowID, minute: reminder.minutes),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAccessReminders(windowID: UUID?) async {
        guard let windowID else {
            let pending = await center.pendingNotificationRequests()
            let identifiers = pending.map(\.identifier).filter { $0.hasPrefix("friend-mvp.access.") }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [10, 30, 60].map {
            identifier(windowID: windowID, minute: $0)
        })
    }

    private func identifier(windowID: UUID, minute: Int) -> String {
        "friend-mvp.access.\(windowID.uuidString).\(minute)"
    }
}

import Foundation

nonisolated enum MonitorEventKind: String, Codable, Equatable, Sendable {
    case intervalStarted
    case intervalEnded
}

nonisolated struct MonitorEvent: Codable, Equatable, Sendable {
    let sequence: Int
    let kind: MonitorEventKind
    let activityName: String
    let createdAt: Date
}

nonisolated struct FocusDeadlineMonitorContext: Codable, Equatable, Sendable {
    let monitorID: UUID
    let activityName: String
    let deadline: Date
}

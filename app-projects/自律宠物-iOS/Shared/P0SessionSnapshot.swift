import Foundation

nonisolated enum P0SessionPhase: String, Codable, Equatable, Sendable {
    case idle
    case configuring
    case localProtectionRequested
    case recoveryRequired
}

nonisolated struct P0SessionSnapshot: Codable, Equatable, Sendable {
    let sessionID: UUID
    var generation: Int
    var phase: P0SessionPhase
    var selectedItemCount: Int
    var lastConsumedIntentID: UUID?
    var lastCommandReceipt: ShieldCommandReceipt?
    var updatedAt: Date
}

import Foundation

nonisolated enum ShieldCommandKind: String, Codable, Equatable, Sendable {
    case apply
    case clear
    case reapply
}

nonisolated enum LocalDispatchState: String, Codable, Equatable, Sendable {
    case invoked
    case preconditionRejected
}

nonisolated struct ShieldCommandReceipt: Codable, Equatable, Sendable {
    let commandID: UUID
    let sessionID: UUID
    let generation: Int
    let kind: ShieldCommandKind
    let requestedAt: Date
    let localDispatch: LocalDispatchState
    let preconditionErrorCode: String?
}

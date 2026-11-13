import Foundation

nonisolated enum ShieldIntentContext: String, Codable, Equatable, Sendable {
    case application
    case category
    case webDomain
}

nonisolated struct PendingShieldIntent: Codable, Equatable, Sendable {
    let context: ShieldIntentContext
}

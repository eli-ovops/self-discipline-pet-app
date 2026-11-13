@preconcurrency import FamilyControls

@MainActor
struct FamilyControlsAuthorizationClient {
    private let center = AuthorizationCenter.shared

    var status: AuthorizationStatus {
        center.authorizationStatus
    }

    func requestIndividualAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }

    func revokeAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.beginRevoke(center: center, continuation: continuation)
        }
    }

    nonisolated private static func beginRevoke(
        center: AuthorizationCenter,
        continuation: CheckedContinuation<Void, Error>
    ) {
        center.revokeAuthorization { result in
            continuation.resume(with: result)
        }
    }
}

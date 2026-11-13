import Foundation

nonisolated enum BetaValidationStoreLoadResult: Equatable, Sendable {
    case loaded(BetaValidationState)
    case recoveryRequired
}

/// Installation-local persistence for the allowlisted Beta validation data.
/// This store has no network client and no account identity.
@MainActor
final class BetaValidationStore {
    private let defaults: UserDefaults
    private let stateKey = "beta-validation.state.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadState() -> BetaValidationStoreLoadResult {
        guard defaults.object(forKey: stateKey) != nil else {
            return .loaded(.fresh())
        }
        guard let data = defaults.data(forKey: stateKey),
              var state = try? decoder.decode(BetaValidationState.self, from: data),
              state.schemaVersion == BetaValidationState.currentSchemaVersion else {
            return .recoveryRequired
        }
        state.normalizeLoadedEventLimit()
        return .loaded(state)
    }

    func save(_ state: BetaValidationState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    func clearAllLocalData() {
        defaults.removeObject(forKey: stateKey)
    }
}

import Foundation

nonisolated enum AppGroupStoreError: Error, Equatable {
    case suiteUnavailable
    case encodingFailed
    case decodingFailed
}

nonisolated struct AppGroupStore {
    private let defaults: UserDefaults

    init(suiteName: String = AppGroupKeys.suiteName) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppGroupStoreError.suiteUnavailable
        }
        self.defaults = defaults
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func write<Value: Encodable>(_ value: Value, forKey key: String) throws {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            throw AppGroupStoreError.encodingFailed
        }
    }

    func read<Value: Decodable>(_ type: Value.Type, forKey key: String) throws -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AppGroupStoreError.decodingFailed
        }
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

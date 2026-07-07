import Foundation

/// Generic UserDefaults persistence for `Codable` arrays.
/// Each feature module's domain-specific store wraps this to satisfy
/// its own typed protocol without repeating the encode/decode boilerplate.
public final class UserDefaultsStore<T: Codable>: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key      = key
    }

    public func load() -> [T] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    public func save(_ items: [T]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Generic in-memory key-value cache.
/// Used by feature repositories to avoid redundant network calls within a session.
/// An actor, not a class — mutable state accessed from concurrent async contexts
/// (repositories called from more than one Task) needs real isolation, not a
/// `class` wrapped in `@unchecked Sendable` on a promise that callers behave.
public actor LocalCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    public init() {}

    public func get(_ key: Key) -> Value? { storage[key] }
    public func set(_ value: Value, for key: Key) { storage[key] = value }
    public func clear() { storage.removeAll() }
}

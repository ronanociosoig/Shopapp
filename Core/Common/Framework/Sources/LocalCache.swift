/// Generic in-memory key-value cache.
/// Used by feature repositories to avoid redundant network calls within a session.
/// Not thread-safe — callers are responsible for confining access to one actor/queue.
public final class LocalCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    public init() {}

    public func get(_ key: Key) -> Value? { storage[key] }
    public func set(_ value: Value, for key: Key) { storage[key] = value }
    public func clear() { storage.removeAll() }
}

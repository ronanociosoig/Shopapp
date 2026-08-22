import Testing
import Foundation
import Common

@Suite("LocalCache")
struct LocalCacheTests {

    // MARK: - Initial state

    @Test("Returns nil for an unknown key")
    func returnsNilInitially() async {
        let cache = LocalCache<String, Int>()
        #expect(await cache.get("missing") == nil)
    }

    // MARK: - Set and get

    @Test("Returns the value that was stored for a key")
    func returnsStoredValue() async {
        let cache = LocalCache<String, Int>()
        await cache.set(42, for: "answer")
        #expect(await cache.get("answer") == 42)
    }

    @Test("Second set for the same key overwrites the first")
    func setOverwritesPreviousValue() async {
        let cache = LocalCache<String, Int>()
        await cache.set(1, for: "key")
        await cache.set(2, for: "key")
        #expect(await cache.get("key") == 2)
    }

    @Test("Different keys are stored and retrieved independently")
    func differentKeysAreIndependent() async {
        let cache = LocalCache<String, Int>()
        await cache.set(10, for: "a")
        await cache.set(20, for: "b")
        #expect(await cache.get("a") == 10)
        #expect(await cache.get("b") == 20)
    }

    // MARK: - Clear

    @Test("clear() removes all entries so every key returns nil")
    func clearRemovesAllValues() async {
        let cache = LocalCache<String, Int>()
        await cache.set(1, for: "a")
        await cache.set(2, for: "b")
        await cache.clear()
        #expect(await cache.get("a") == nil)
        #expect(await cache.get("b") == nil)
    }

    @Test("clear() on an empty cache does not crash")
    func clearOnEmptyCacheIsNoop() async {
        let cache = LocalCache<String, Int>()
        await cache.clear() // must not crash
    }

    // MARK: - Different key/value types

    @Test("Works with UUID keys")
    func supportsUUIDKeys() async {
        let cache = LocalCache<UUID, String>()
        let id = UUID()
        await cache.set("hello", for: id)
        #expect(await cache.get(id) == "hello")
        #expect(await cache.get(UUID()) == nil)
    }

    @Test("Works with array values")
    func supportsArrayValues() async {
        let cache = LocalCache<String, [Int]>()
        await cache.set([1, 2, 3], for: "list")
        #expect(await cache.get("list") == [1, 2, 3])
    }
}

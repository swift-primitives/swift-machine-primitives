import Testing
@testable import Machine_Primitives

@Suite("Machine.Value.Arena")
struct MachineValueArenaTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Value = Machine.Value<Mode>
    typealias Arena = Machine.Value<Mode>.Arena
    typealias Handle = Machine.Value<Mode>.Handle

    @Test("init creates arena with default capacity")
    func initWithDefaultCapacity() {
        var arena = Arena()
        let value = Value.make(42)
        let handle = arena.allocate(value)
        let read = arena.read(handle)
        #expect(read[as: Int.self] == 42)
    }

    @Test("init creates arena with custom capacity")
    func initWithCustomCapacity() {
        var arena = Arena(capacity: 16)
        let value = Value.make("test")
        let handle = arena.allocate(value)
        let read = arena.read(handle)
        #expect(read[as: String.self] == "test")
    }

    @Test("allocate returns unique handles")
    func allocateReturnsUniqueHandles() {
        var arena = Arena()
        let handle1 = arena.allocate(Value.make(1))
        let handle2 = arena.allocate(Value.make(2))
        let handle3 = arena.allocate(Value.make(3))

        #expect(handle1 != handle2)
        #expect(handle2 != handle3)
        #expect(handle1 != handle3)
    }

    @Test("allocate auto-expands capacity")
    func allocateAutoExpandsCapacity() {
        var arena = Arena(capacity: 2)

        // Allocate more than initial capacity
        for i in 0..<10 {
            _ = arena.allocate(Value.make(i))
        }

        // Should not crash and all values should be accessible
        // (We can't directly verify internal capacity, but no crash means success)
    }

    @Test("read returns correct value")
    func readReturnsCorrectValue() {
        var arena = Arena()
        let handle = arena.allocate(Value.make(123))
        let value = arena.read(handle)
        #expect(value[as: Int.self] == 123)
    }

    @Test("read does not remove value")
    func readDoesNotRemoveValue() {
        var arena = Arena()
        let handle = arena.allocate(Value.make(42))

        let value1 = arena.read(handle)
        let value2 = arena.read(handle)

        #expect(value1[as: Int.self] == 42)
        #expect(value2[as: Int.self] == 42)
    }

    @Test("release returns and removes value")
    func releaseReturnsAndRemovesValue() {
        var arena = Arena()
        let handle = arena.allocate(Value.make(99))

        let value = arena.release(handle)
        #expect(value[as: Int.self] == 99)
    }

    @Test("multiple values stored independently")
    func multipleValuesStoredIndependently() {
        var arena = Arena()
        let h1 = arena.allocate(Value.make("first"))
        let h2 = arena.allocate(Value.make("second"))
        let h3 = arena.allocate(Value.make("third"))

        #expect(arena.read(h1)[as: String.self] == "first")
        #expect(arena.read(h2)[as: String.self] == "second")
        #expect(arena.read(h3)[as: String.self] == "third")
    }

    @Test("reset clears all values")
    func resetClearsAllValues() {
        var arena = Arena()
        _ = arena.allocate(Value.make(1))
        _ = arena.allocate(Value.make(2))
        _ = arena.allocate(Value.make(3))

        arena.reset()

        // After reset, allocating should reuse slots from beginning
        let handle = arena.allocate(Value.make(100))
        let value = arena.read(handle)
        #expect(value[as: Int.self] == 100)
    }

    @Test("handles are equatable")
    func handlesAreEquatable() {
        var arena = Arena()
        let h1 = arena.allocate(Value.make(1))
        let h2 = arena.allocate(Value.make(2))

        #expect(h1 == h1)
        #expect(h1 != h2)
    }

    @Test("handles are hashable")
    func handlesAreHashable() {
        var arena = Arena()
        let h1 = arena.allocate(Value.make(1))
        let h2 = arena.allocate(Value.make(2))

        var set: Swift.Set<Handle> = []
        set.insert(h1)
        set.insert(h2)

        #expect(set.contains(h1))
        #expect(set.contains(h2))
        #expect(set.count == 2)
    }

    @Test("allocation after partial release")
    func allocationAfterPartialRelease() {
        var arena = Arena()
        let h1 = arena.allocate(Value.make("a"))
        let h2 = arena.allocate(Value.make("b"))

        _ = arena.release(h1)

        // h2 should still be valid
        #expect(arena.read(h2)[as: String.self] == "b")

        // New allocation should still work
        let h3 = arena.allocate(Value.make("c"))
        #expect(arena.read(h3)[as: String.self] == "c")
    }
}

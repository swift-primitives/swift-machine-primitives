import Testing
@testable import Machine_Primitives

@Suite("Machine.Finalize.Array")
struct MachineFinalizeArrayTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias Finalize = Machine.Finalize.Array<Mode>

    @Test("finalize converts values to typed array")
    func finalizeConvertsValuesToTypedArray() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(1),
            Value.make(2),
            Value.make(3)
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result.take([Int].self) == [1, 2, 3])
    }

    @Test("finalize with empty array")
    func finalizeWithEmptyArray() {
        var store = Store()
        let finalize = Finalize(elementType: String.self, store: &store)
        let frozen = store.freeze()

        let values: [Value] = []
        let result = finalize.finalize(using: frozen, values)
        #expect(result.take([String].self) == [])
    }

    @Test("finalize with single element")
    func finalizeWithSingleElement() {
        var store = Store()
        let finalize = Finalize(elementType: Double.self, store: &store)
        let frozen = store.freeze()

        let values = [Value.make(3.14)]
        let result = finalize.finalize(using: frozen, values)
        #expect(result.take([Double].self) == [3.14])
    }

    @Test("finalize with string values")
    func finalizeWithStringValues() {
        var store = Store()
        let finalize = Finalize(elementType: String.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make("hello"),
            Value.make("world")
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result.take([String].self) == ["hello", "world"])
    }

    @Test("finalize with custom struct")
    func finalizeWithCustomStruct() {
        struct Item: Equatable, Sendable { var id: Int }

        var store = Store()
        let finalize = Finalize(elementType: Item.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(Item(id: 1)),
            Value.make(Item(id: 2)),
            Value.make(Item(id: 3))
        ]
        let result = finalize.finalize(using: frozen, values)

        let items = result.take([Item].self)
        #expect(items == [Item(id: 1), Item(id: 2), Item(id: 3)])
    }

    @Test("finalize preserves order")
    func finalizePreservesOrder() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(5),
            Value.make(3),
            Value.make(1),
            Value.make(4),
            Value.make(2)
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result.take([Int].self) == [5, 3, 1, 4, 2])
    }

    @Test("finalize with optional elements")
    func finalizeWithOptionalElements() {
        var store = Store()
        let finalize = Finalize(elementType: Int?.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(Int?(1)),
            Value.make(Int?(nil)),
            Value.make(Int?(3))
        ]
        let result = finalize.finalize(using: frozen, values)

        let array = result.take([Int?].self)
        #expect(array?[0] == 1)
        #expect(array?[1] == nil)
        #expect(array?[2] == 3)
    }

    @Test("finalize with tuple elements")
    func finalizeWithTupleElements() {
        var store = Store()
        let finalize = Finalize(elementType: (Int, String).self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make((1, "one")),
            Value.make((2, "two"))
        ]
        let result = finalize.finalize(using: frozen, values)

        let array = result.take([(Int, String)].self)
        #expect(array?.count == 2)
        #expect(array?[0].0 == 1)
        #expect(array?[0].1 == "one")
        #expect(array?[1].0 == 2)
        #expect(array?[1].1 == "two")
    }

    @Test("finalize large array")
    func finalizeLargeArray() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = (0..<100).map { Value.make($0) }
        let result = finalize.finalize(using: frozen, values)

        let array = result.take([Int].self)
        #expect(array?.count == 100)
        #expect(array?[0] == 0)
        #expect(array?[99] == 99)
    }
}

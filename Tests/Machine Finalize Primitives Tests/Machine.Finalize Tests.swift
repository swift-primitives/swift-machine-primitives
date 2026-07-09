import Testing

@testable import Machine_Primitives

@Suite
struct `Machine.Finalize.Array Tests` {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias Finalize = Machine.Finalize.Array<Mode>

    @Test
    func `finalize converts values to typed array`() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(1),
            Value.make(2),
            Value.make(3),
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result[as: [Int].self] == [1, 2, 3])
    }

    @Test
    func `finalize with empty array`() {
        var store = Store()
        let finalize = Finalize(elementType: String.self, store: &store)
        let frozen = store.freeze()

        let values: [Value] = []
        let result = finalize.finalize(using: frozen, values)
        #expect(result[as: [String].self] == [])
    }

    @Test
    func `finalize with single element`() {
        var store = Store()
        let finalize = Finalize(elementType: Double.self, store: &store)
        let frozen = store.freeze()

        let values = [Value.make(3.14)]
        let result = finalize.finalize(using: frozen, values)
        #expect(result[as: [Double].self] == [3.14])
    }

    @Test
    func `finalize with string values`() {
        var store = Store()
        let finalize = Finalize(elementType: String.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make("hello"),
            Value.make("world"),
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result[as: [String].self] == ["hello", "world"])
    }

    @Test
    func `finalize with custom struct`() {
        struct Item: Equatable, Sendable { var id: Int }

        var store = Store()
        let finalize = Finalize(elementType: Item.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(Item(id: 1)),
            Value.make(Item(id: 2)),
            Value.make(Item(id: 3)),
        ]
        let result = finalize.finalize(using: frozen, values)

        let items = result[as: [Item].self]
        #expect(items == [Item(id: 1), Item(id: 2), Item(id: 3)])
    }

    @Test
    func `finalize preserves order`() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(5),
            Value.make(3),
            Value.make(1),
            Value.make(4),
            Value.make(2),
        ]
        let result = finalize.finalize(using: frozen, values)
        #expect(result[as: [Int].self] == [5, 3, 1, 4, 2])
    }

    @Test
    func `finalize with optional elements`() {
        var store = Store()
        let finalize = Finalize(elementType: Int?.self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make(Int?(1)),
            Value.make(Int?(nil)),
            Value.make(Int?(3)),
        ]
        let result = finalize.finalize(using: frozen, values)

        let array = result[as: [Int?].self]
        #expect(array[0] == 1)
        #expect(array[1] == nil)
        #expect(array[2] == 3)
    }

    @Test
    func `finalize with tuple elements`() {
        var store = Store()
        let finalize = Finalize(elementType: (Int, String).self, store: &store)
        let frozen = store.freeze()

        let values = [
            Value.make((1, "one")),
            Value.make((2, "two")),
        ]
        let result = finalize.finalize(using: frozen, values)

        let array = result[as: [(Int, String)].self]
        #expect(array.count == 2)
        #expect(array[0].0 == 1)
        #expect(array[0].1 == "one")
        #expect(array[1].0 == 2)
        #expect(array[1].1 == "two")
    }

    @Test
    func `finalize large array`() {
        var store = Store()
        let finalize = Finalize(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let values = (0..<100).map { Value.make($0) }
        let result = finalize.finalize(using: frozen, values)

        let array = result[as: [Int].self]
        #expect(array.count == 100)
        #expect(array[0] == 0)
        #expect(array[99] == 99)
    }
}

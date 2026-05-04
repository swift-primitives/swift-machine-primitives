import Testing

@testable import Machine_Primitives

@Suite("Machine.Combine.Erased")
struct MachineCombineErasedTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias Combine = Machine.Combine.Erased<Mode>

    @Test
    func `combine two integers into sum`() {
        var store = Store()
        let captureID = store.insert({ (a: Int, b: Int) in a + b } as @Sendable (Int, Int) -> Int)
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make(10)
        let b = Value.make(20)
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: Int.self] == 30)
    }

    @Test
    func `combine different types into tuple`() {
        var store = Store()
        let captureID = store.insert({ (a: Int, b: String) in (a, b) } as @Sendable (Int, String) -> (Int, String))
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make(42)
        let b = Value.make("hello")
        let result = combine.combine(using: frozen, a, b)

        let tuple = result[as: (Int, String).self]
        #expect(tuple.0 == 42)
        #expect(tuple.1 == "hello")
    }

    @Test
    func `combine strings with concatenation`() {
        var store = Store()
        let captureID = store.insert({ (a: String, b: String) in a + b } as @Sendable (String, String) -> String)
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make("Hello, ")
        let b = Value.make("World!")
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: String.self] == "Hello, World!")
    }

    @Test
    func `combine into custom struct`() {
        struct Point: Sendable {
            var x: Int
            var y: Int
        }

        var store = Store()
        let captureID = store.insert({ (x: Int, y: Int) in Point(x: x, y: y) } as @Sendable (Int, Int) -> Point)
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let x = Value.make(10)
        let y = Value.make(20)
        let result = combine.combine(using: frozen, x, y)

        let point = result[as: Point.self]
        #expect(point.x == 10)
        #expect(point.y == 20)
    }

    @Test
    func `combine arrays into combined array`() {
        var store = Store()
        let captureID = store.insert({ (a: [Int], b: [Int]) in a + b } as @Sendable ([Int], [Int]) -> [Int])
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make([1, 2, 3])
        let b = Value.make([4, 5, 6])
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: [Int].self] == [1, 2, 3, 4, 5, 6])
    }

    @Test
    func `combine discarding first value`() {
        var store = Store()
        let captureID = store.insert({ (_: Int, b: String) in b } as @Sendable (Int, String) -> String)
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make(42)
        let b = Value.make("keep me")
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: String.self] == "keep me")
    }

    @Test
    func `combine discarding second value`() {
        var store = Store()
        let captureID = store.insert({ (a: String, _: Int) in a } as @Sendable (String, Int) -> String)
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make("keep me")
        let b = Value.make(42)
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: String.self] == "keep me")
    }

    @Test
    func `combine with closure capture`() {
        let separator = "-"
        var store = Store()
        let captureID = store.insert(
            { (a: String, b: String) in
                a + separator + b
            } as @Sendable (String, String) -> String
        )
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make("left")
        let b = Value.make("right")
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: String.self] == "left-right")
    }

    @Test
    func `combine into optional`() {
        var store = Store()
        let captureID = store.insert(
            { (a: Int, b: Int) -> Int? in
                let sum = a + b
                return sum > 0 ? sum : nil
            } as @Sendable (Int, Int) -> Int?
        )
        let combine = Combine(capture: captureID)
        let frozen = store.freeze()

        let a = Value.make(5)
        let b = Value.make(10)
        let result = combine.combine(using: frozen, a, b)
        #expect(result[as: Int?.self] == 15)
    }
}

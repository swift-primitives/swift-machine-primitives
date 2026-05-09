import Testing

@testable import Machine_Primitives

// WORKAROUND: Swift 6.3.1 SILGen crashes (signal 5, `createInputFunctionArgument` /
// `LoweredParamGenerator::claimNext`) when a typed-throws `@Sendable` closure
// literal is passed — via an inline `as @Sendable (In) throws(E) -> Out` cast —
// into `Store.insert<V: Sendable>(_:)`. This overload's concrete function-typed
// parameter absorbs the closure at the call site (no `as` needed), and the nested
// generic `dispatchToBase` routes the stored value through the primary `<V: Sendable>`
// method — generic parameter `V` is opaque inside `dispatchToBase`, so the outer
// typed-throws overload cannot match and recursion is impossible.
// REVISIT: remove once the inline-cast form is accepted by SILGen. Minimal
// reproducer: `swift-institute/Experiments/silgen-sendable-typed-throws-closure-cast/`.
extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference {
    fileprivate mutating func insert<In: Sendable, Out: Sendable, E: Swift.Error>(
        _ fn: @Sendable @escaping (In) throws(E) -> Out
    ) -> Machine.Capture.ID<@Sendable (In) throws(E) -> Out> {
        func dispatchToBase<V: Sendable>(_ v: V) -> Machine.Capture.ID<V> { self.insert(v) }
        return dispatchToBase(fn)
    }
}

@Suite("Machine.Transform.Erased")
struct MachineTransformErasedTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Value = Machine.Value<Mode>
    typealias Store = Machine.Capture.Store<Mode>
    typealias Frozen = Machine.Capture.Frozen<Mode>
    typealias Transform = Machine.Transform.Erased<Mode>

    @Test
    func `apply transforms value correctly`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(21)
        let output = transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 42)
    }

    @Test
    func `apply changes type`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in String(x) } as @Sendable (Int) -> String)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(123)
        let output = transform.apply(using: frozen, input)
        #expect(output[as: String.self] == "123")
    }

    @Test
    func `identity transform`() {
        var store = Store()
        let captureID = store.insert({ (x: String) in x } as @Sendable (String) -> String)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("unchanged")
        let output = transform.apply(using: frozen, input)
        #expect(output[as: String.self] == "unchanged")
    }

    @Test
    func `transform with closure capturing context`() {
        let multiplier = 10
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * multiplier } as @Sendable (Int) -> Int)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        let output = transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 50)
    }

    @Test
    func `transform struct to different struct`() {
        struct Input: Sendable { var value: Int }
        struct Output: Sendable { var doubled: Int }

        var store = Store()
        let captureID = store.insert(
            { (input: Input) in
                Output(doubled: input.value * 2)
            } as @Sendable (Input) -> Output
        )
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(Input(value: 7))
        let output = transform.apply(using: frozen, input)

        #expect(output[as: Output.self].doubled == 14)
    }

    @Test
    func `transform to optional`() {
        var store = Store()
        let captureID = store.insert(
            { (x: Int) -> Int? in
                x > 0 ? x : nil
            } as @Sendable (Int) -> Int?
        )
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        let output = transform.apply(using: frozen, input)
        #expect(output[as: Int?.self] == 5)
    }

    @Test
    func `transform array`() {
        var store = Store()
        let captureID = store.insert({ (arr: [Int]) in arr.map { $0 * 2 } } as @Sendable ([Int]) -> [Int])
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make([1, 2, 3])
        let output = transform.apply(using: frozen, input)
        #expect(output[as: [Int].self] == [2, 4, 6])
    }
}

@Suite("Machine.Transform.Throwing")
struct MachineTransformThrowingTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Value = Machine.Value<Mode>
    typealias Store = Machine.Capture.Store<Mode>
    typealias Frozen = Machine.Capture.Frozen<Mode>

    enum TestError: Swift.Error, Equatable, Sendable {
        case negativeValue
        case overflow
    }

    typealias ThrowingTransform = Machine.Transform.Throwing<Mode, TestError>

    @Test
    func `apply succeeds for valid input`() throws {
        var store = Store()
        let captureID = store.insert { (x: Int) throws(TestError) -> Int in
            guard x >= 0 else { throw .negativeValue }
            return x * 2
        }
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(21)
        let output = try transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 42)
    }

    @Test
    func `apply throws for invalid input`() {
        var store = Store()
        let captureID = store.insert { (x: Int) throws(TestError) -> Int in
            guard x >= 0 else { throw .negativeValue }
            return x * 2
        }
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(-5)

        #expect(throws: TestError.negativeValue) {
            try transform.apply(using: frozen, input)
        }
    }

    @Test
    func `apply changes type with throwing`() throws {
        var store = Store()
        let captureID = store.insert { (x: String) throws(TestError) -> Int in
            guard let parsed = Int(x) else { throw .overflow }
            return parsed
        }
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("42")
        let output = try transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 42)
    }

    @Test
    func `transform with different error types`() throws {
        enum ParseError: Swift.Error, Sendable { case invalid }
        typealias ParseTransform = Machine.Transform.Throwing<Mode, ParseError>

        var store = Store()
        let captureID = store.insert { (s: String) throws(ParseError) -> Int in
            guard let n = Int(s) else { throw .invalid }
            return n
        }
        let transform = ParseTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("99")
        let output = try transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 99)
    }

    @Test
    func `transform preserves value on success`() throws {
        var store = Store()
        let captureID = store.insert { (s: String) throws(TestError) -> String in
            s.uppercased()
        }
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("hello")
        let output = try transform.apply(using: frozen, input)
        #expect(output[as: String.self] == "HELLO")
    }

    @Test
    func `throwing transform with closure capture`() throws {
        let maxValue = 100
        var store = Store()
        let captureID = store.insert { (x: Int) throws(TestError) -> Int in
            guard x <= maxValue else { throw .overflow }
            return x
        }
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(50)
        let output = try transform.apply(using: frozen, input)
        #expect(output[as: Int.self] == 50)
    }
}

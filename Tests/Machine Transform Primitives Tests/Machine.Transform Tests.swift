import Testing
@testable import Machine_Primitives

@Suite("Machine.Transform.Erased")
struct MachineTransformErasedTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Value = Machine.Value<Mode>
    typealias Store = Machine.Capture.Store<Mode>
    typealias Frozen = Machine.Capture.Frozen<Mode>
    typealias Transform = Machine.Transform.Erased<Mode>

    @Test("apply transforms value correctly")
    func applyTransformsValue() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(21)
        let output = transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 42)
    }

    @Test("apply changes type")
    func applyChangesType() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in String(x) } as @Sendable (Int) -> String)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(123)
        let output = transform.apply(using: frozen, input)
        #expect(output.take(String.self) == "123")
    }

    @Test("identity transform")
    func identityTransform() {
        var store = Store()
        let captureID = store.insert({ (x: String) in x } as @Sendable (String) -> String)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("unchanged")
        let output = transform.apply(using: frozen, input)
        #expect(output.take(String.self) == "unchanged")
    }

    @Test("transform with closure capturing context")
    func transformWithCapture() {
        let multiplier = 10
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * multiplier } as @Sendable (Int) -> Int)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        let output = transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 50)
    }

    @Test("transform struct to different struct")
    func transformStructToStruct() {
        struct Input: Sendable { var value: Int }
        struct Output: Sendable { var doubled: Int }

        var store = Store()
        let captureID = store.insert({ (input: Input) in
            Output(doubled: input.value * 2)
        } as @Sendable (Input) -> Output)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(Input(value: 7))
        let output = transform.apply(using: frozen, input)

        #expect(output.take(Output.self)?.doubled == 14)
    }

    @Test("transform to optional")
    func transformToOptional() {
        var store = Store()
        let captureID = store.insert({ (x: Int) -> Int? in
            x > 0 ? x : nil
        } as @Sendable (Int) -> Int?)
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        let output = transform.apply(using: frozen, input)
        #expect(output.take(Int?.self) == 5)
    }

    @Test("transform array")
    func transformArray() {
        var store = Store()
        let captureID = store.insert({ (arr: [Int]) in arr.map { $0 * 2 } } as @Sendable ([Int]) -> [Int])
        let transform = Transform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make([1, 2, 3])
        let output = transform.apply(using: frozen, input)
        #expect(output.take([Int].self) == [2, 4, 6])
    }
}

@Suite("Machine.Transform.Throwing")
struct MachineTransformThrowingTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Value = Machine.Value<Mode>
    typealias Store = Machine.Capture.Store<Mode>
    typealias Frozen = Machine.Capture.Frozen<Mode>

    enum TestError: Error, Equatable, Sendable {
        case negativeValue
        case overflow
    }

    typealias ThrowingTransform = Machine.Transform.Throwing<Mode, TestError>

    @Test("apply succeeds for valid input")
    func applySucceeds() throws {
        var store = Store()
        let captureID = store.insert({ (x: Int) throws(TestError) in
            guard x >= 0 else { throw .negativeValue }
            return x * 2
        } as @Sendable (Int) throws(TestError) -> Int)
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(21)
        let output = try transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 42)
    }

    @Test("apply throws for invalid input")
    func applyThrows() {
        var store = Store()
        let captureID = store.insert({ (x: Int) throws(TestError) in
            guard x >= 0 else { throw .negativeValue }
            return x * 2
        } as @Sendable (Int) throws(TestError) -> Int)
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(-5)

        #expect(throws: TestError.negativeValue) {
            try transform.apply(using: frozen, input)
        }
    }

    @Test("apply changes type with throwing")
    func applyChangesTypeWithThrowing() throws {
        var store = Store()
        let captureID = store.insert({ (x: String) throws(TestError) -> Int in
            guard let parsed = Int(x) else { throw .overflow }
            return parsed
        } as @Sendable (String) throws(TestError) -> Int)
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("42")
        let output = try transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 42)
    }

    @Test("transform with different error types")
    func transformWithDifferentErrorTypes() throws {
        enum ParseError: Error, Sendable { case invalid }
        typealias ParseTransform = Machine.Transform.Throwing<Mode, ParseError>

        var store = Store()
        let captureID = store.insert({ (s: String) throws(ParseError) in
            guard let n = Int(s) else { throw .invalid }
            return n
        } as @Sendable (String) throws(ParseError) -> Int)
        let transform = ParseTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("99")
        let output = try transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 99)
    }

    @Test("transform preserves value on success")
    func transformPreservesValueOnSuccess() throws {
        var store = Store()
        let captureID = store.insert({ (s: String) throws(TestError) in
            s.uppercased()
        } as @Sendable (String) throws(TestError) -> String)
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make("hello")
        let output = try transform.apply(using: frozen, input)
        #expect(output.take(String.self) == "HELLO")
    }

    @Test("throwing transform with closure capture")
    func throwingTransformWithCapture() throws {
        let maxValue = 100
        var store = Store()
        let captureID = store.insert({ (x: Int) throws(TestError) in
            guard x <= maxValue else { throw .overflow }
            return x
        } as @Sendable (Int) throws(TestError) -> Int)
        let transform = ThrowingTransform(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(50)
        let output = try transform.apply(using: frozen, input)
        #expect(output.take(Int.self) == 50)
    }
}

import Testing
@testable import Machine_Primitives

@Suite("Machine.Next.Erased")
struct MachineNextErasedTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>

    @Test
    func `next selects node based on input`() {
        var store = Store()
        let captureID = store.insert({ (value: Bool) in value ? 1 : 0 } as @Sendable (Bool) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let trueValue = Value.make(true)
        let falseValue = Value.make(false)

        #expect(next.next(using: frozen, trueValue) == 1)
        #expect(next.next(using: frozen, falseValue) == 0)
    }

    @Test
    func `next with integer input`() {
        var store = Store()
        let captureID = store.insert({ (index: Int) in index * 10 } as @Sendable (Int) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        #expect(next.next(using: frozen, input) == 50)
    }

    @Test
    func `next with string pattern matching`() {
        var store = Store()
        let captureID = store.insert({ (s: String) in
            switch s {
            case "a": return 0
            case "b": return 1
            default: return -1
            }
        } as @Sendable (String) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        #expect(next.next(using: frozen, Value.make("a")) == 0)
        #expect(next.next(using: frozen, Value.make("b")) == 1)
        #expect(next.next(using: frozen, Value.make("c")) == -1)
    }

    @Test
    func `next with custom node ID type`() {
        struct NodeID: Equatable, Sendable {
            let value: Int
        }

        var store = Store()
        let captureID = store.insert({ (x: Int) in NodeID(value: x) } as @Sendable (Int) -> NodeID)
        let next = Machine.Next.Erased<Mode, NodeID>(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(42)
        #expect(next.next(using: frozen, input) == NodeID(value: 42))
    }

    @Test
    func `next with closure capture`() {
        let offset = 100
        var store = Store()
        let captureID = store.insert({ (x: Int) in x + offset } as @Sendable (Int) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(5)
        #expect(next.next(using: frozen, input) == 105)
    }

    @Test
    func `next with struct input`() {
        struct Choice: Sendable { var index: Int }

        var store = Store()
        let captureID = store.insert({ (choice: Choice) in choice.index } as @Sendable (Choice) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(Choice(index: 7))
        #expect(next.next(using: frozen, input) == 7)
    }

    @Test
    func `next with optional unwrap`() {
        var store = Store()
        let captureID = store.insert({ (opt: Int?) in opt ?? -1 } as @Sendable (Int?) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let someValue = Value.make(Int?(42))
        let noneValue = Value.make(Int?(nil))

        #expect(next.next(using: frozen, someValue) == 42)
        #expect(next.next(using: frozen, noneValue) == -1)
    }

    @Test
    func `next with enum discriminant`() {
        enum Token: Sendable { case number, string, symbol }

        var store = Store()
        let captureID = store.insert({ (token: Token) in
            switch token {
            case .number: return 0
            case .string: return 1
            case .symbol: return 2
            }
        } as @Sendable (Token) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        #expect(next.next(using: frozen, Value.make(Token.number)) == 0)
        #expect(next.next(using: frozen, Value.make(Token.string)) == 1)
        #expect(next.next(using: frozen, Value.make(Token.symbol)) == 2)
    }

    @Test
    func `next with array count`() {
        var store = Store()
        let captureID = store.insert({ (arr: [String]) in arr.count } as @Sendable ([String]) -> Int)
        let next = Machine.Next.Erased<Mode, Int>(capture: captureID)
        let frozen = store.freeze()

        let input = Value.make(["a", "b", "c"])
        #expect(next.next(using: frozen, input) == 3)
    }
}

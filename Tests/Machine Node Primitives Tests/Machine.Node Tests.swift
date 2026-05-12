import Testing

@testable import Machine_Primitives

// WORKAROUND for a Swift 6.3.1 SILGen crash (signal 5) on
// `store.insert({ ... } as @Sendable (T) throws(E) -> U)`. See
// `swift-institute/Experiments/silgen-sendable-typed-throws-closure-cast/`.
extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference {
    fileprivate mutating func insert<In: Sendable, Out: Sendable, E: Swift.Error>(
        _ fn: @Sendable @escaping (In) throws(E) -> Out
    ) -> Machine.Capture.ID<@Sendable (In) throws(E) -> Out> {
        func dispatchToBase<V: Sendable>(_ v: V) -> Machine.Capture.ID<V> { self.insert(v) }
        return dispatchToBase(fn)
    }
}

@Suite("Machine.Node")
struct MachineNodeTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Frozen = Machine.Capture.Frozen<Mode>
    typealias Value = Machine.Value<Mode>

    enum TestLeaf: Equatable, Sendable {
        case readByte
        case readInt
        case advance(Int)
    }

    enum TestError: Swift.Error, Equatable, Sendable {
        case unexpected
        case overflow
    }

    typealias TestNode = Machine.Node<TestLeaf, TestError, Mode>
    typealias ID = TestNode.ID

    @Test
    func `leaf stores leaf value`() {
        let node: TestNode = .leaf(.readByte)

        if case .leaf(let leaf) = node {
            #expect(leaf == .readByte)
        } else {
            Issue.record("Expected leaf case")
        }
    }

    @Test
    func `leaf with associated value`() {
        let node: TestNode = .leaf(.advance(10))

        if case .leaf(let leaf) = node {
            #expect(leaf == .advance(10))
        } else {
            Issue.record("Expected leaf case")
        }
    }

    @Test
    func `pure stores value`() {
        let value = Value.make(42)
        let node: TestNode = .pure(value)

        if case .pure(let v) = node {
            #expect(v[as: Int.self] == 42)
        } else {
            Issue.record("Expected pure case")
        }
    }

    @Test
    func `map stores child and transform`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Machine.Transform.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let childId = ID(0)
        let node: TestNode = .map(child: childId, transform: transform)

        if case .map(let child, let t) = node {
            #expect(child == childId)
            // Verify transform works
            let result = t.apply(using: frozen, Value.make(21))
            #expect(result[as: Int.self] == 42)
        } else {
            Issue.record("Expected map case")
        }
    }

    @Test
    func `tryMap stores child and throwing transform`() throws {
        var store = Store()
        let captureID = store.insert { (x: Int) throws(TestError) -> Int in
            guard x >= 0 else { throw .unexpected }
            return x
        }
        let transform = Machine.Transform.Throwing<Mode, TestError>(capture: captureID)
        let frozen = store.freeze()

        let childId = ID(1)
        let node: TestNode = .tryMap(child: childId, transform: transform)

        if case .tryMap(let child, let t) = node {
            #expect(child == childId)
            // Verify transform works
            let result = try t.apply(using: frozen, Value.make(10))
            #expect(result[as: Int.self] == 10)
        } else {
            Issue.record("Expected tryMap case")
        }
    }

    @Test
    func `flatMap stores child and next function`() {
        var store = Store()
        let captureID = store.insert({ (x: Bool) in x ? ID(10) : ID(20) } as @Sendable (Bool) -> ID)
        let next = Machine.Next.Erased<Mode, ID>(capture: captureID)
        let frozen = store.freeze()

        let childId = ID(2)
        let node: TestNode = .flatMap(child: childId, next: next)

        if case .flatMap(let child, let n) = node {
            #expect(child == childId)
            #expect(n.next(using: frozen, Value.make(true)) == ID(10))
            #expect(n.next(using: frozen, Value.make(false)) == ID(20))
        } else {
            Issue.record("Expected flatMap case")
        }
    }

    @Test
    func `sequence stores both children and combine`() {
        var store = Store()
        let captureID = store.insert({ (a: Int, b: Int) in a + b } as @Sendable (Int, Int) -> Int)
        let combine = Machine.Combine.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let aId = ID(0)
        let bId = ID(1)
        let node: TestNode = .sequence(a: aId, b: bId, combine: combine)

        if case .sequence(let a, let b, let c) = node {
            #expect(a == aId)
            #expect(b == bId)
            let result = c.combine(using: frozen, Value.make(10), Value.make(20))
            #expect(result[as: Int.self] == 30)
        } else {
            Issue.record("Expected sequence case")
        }
    }

    @Test
    func `oneOf stores alternatives array`() {
        let alternatives = [ID(0), ID(1), ID(2)]
        let node: TestNode = .oneOf(alternatives)

        if case .oneOf(let alts) = node {
            #expect(alts == alternatives)
        } else {
            Issue.record("Expected oneOf case")
        }
    }

    @Test
    func `oneOf with empty alternatives`() {
        let node: TestNode = .oneOf([])

        if case .oneOf(let alts) = node {
            #expect(alts.isEmpty)
        } else {
            Issue.record("Expected oneOf case")
        }
    }

    @Test
    func `many stores child and finalize`() {
        var store = Store()
        let finalize = Machine.Finalize.Array<Mode>(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let childId = ID(5)
        let node: TestNode = .many(child: childId, finalize: finalize)

        if case .many(let child, let f) = node {
            #expect(child == childId)
            // Verify finalize works
            let values = [Value.make(1), Value.make(2)]
            let result = f.finalize(using: frozen, values)
            #expect(result[as: [Int].self] == [1, 2])
        } else {
            Issue.record("Expected many case")
        }
    }

    @Test
    func `optional stores child, wrapSome, and noneValue`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x as Int? } as @Sendable (Int) -> Int?)
        let wrapSome = Machine.Transform.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let childId = ID(3)
        let noneValue = Value.make(Int?(nil))
        let node: TestNode = .optional(child: childId, wrapSome: wrapSome, noneValue: noneValue)

        if case .optional(let child, let wrap, let none) = node {
            #expect(child == childId)
            // Verify wrapSome works
            let wrapped = wrap.apply(using: frozen, Value.make(42))
            #expect(wrapped[as: Int?.self] == 42)
            // Verify noneValue
            #expect(none[as: Int?.self] == nil)
        } else {
            Issue.record("Expected optional case")
        }
    }

    @Test
    func `ref stores target ID`() {
        let targetId = ID(99)
        let node: TestNode = .ref(targetId)

        if case .ref(let target) = node {
            #expect(target == targetId)
        } else {
            Issue.record("Expected ref case")
        }
    }

    @Test
    func `hole is placeholder`() {
        let node: TestNode = .hole

        if case .hole = node {
            // Success - hole is a valid case
        } else {
            Issue.record("Expected hole case")
        }
    }

    @Test
    func `Node.ID is Tagged<Tag, Int>`() {
        let id1 = ID(42)
        let id2 = ID(42)
        let id3 = ID(0)

        #expect(id1 == id2)
        #expect(id1 != id3)
        #expect(id1.underlying == 42)
    }

    @Test
    func `Node.ID comparison`() {
        let id1 = ID(1)
        let id2 = ID(2)
        let id3 = ID(1)

        #expect(id1 == id3)
        #expect(id1 != id2)
    }
}

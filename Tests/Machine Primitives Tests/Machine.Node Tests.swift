import Testing
@testable import Machine_Primitives

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

    enum TestError: Error, Equatable, Sendable {
        case unexpected
        case overflow
    }

    typealias TestNode = Machine.Node<TestLeaf, TestError, Mode>
    typealias ID = TestNode.ID

    @Test("leaf stores leaf value")
    func leafStoresLeafValue() {
        let node: TestNode = .leaf(.readByte)

        if case .leaf(let leaf) = node {
            #expect(leaf == .readByte)
        } else {
            Issue.record("Expected leaf case")
        }
    }

    @Test("leaf with associated value")
    func leafWithAssociatedValue() {
        let node: TestNode = .leaf(.advance(10))

        if case .leaf(let leaf) = node {
            #expect(leaf == .advance(10))
        } else {
            Issue.record("Expected leaf case")
        }
    }

    @Test("pure stores value")
    func pureStoresValue() {
        let value = Value.make(42)
        let node: TestNode = .pure(value)

        if case .pure(let v) = node {
            #expect(v.take(Int.self) == 42)
        } else {
            Issue.record("Expected pure case")
        }
    }

    @Test("map stores child and transform")
    func mapStoresChildAndTransform() {
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
            #expect(result.take(Int.self) == 42)
        } else {
            Issue.record("Expected map case")
        }
    }

    @Test("tryMap stores child and throwing transform")
    func tryMapStoresChildAndThrowingTransform() throws {
        var store = Store()
        let captureID = store.insert({ (x: Int) throws(TestError) in
            guard x >= 0 else { throw .unexpected }
            return x
        } as @Sendable (Int) throws(TestError) -> Int)
        let transform = Machine.Transform.Throwing<Mode, TestError>(capture: captureID)
        let frozen = store.freeze()

        let childId = ID(1)
        let node: TestNode = .tryMap(child: childId, transform: transform)

        if case .tryMap(let child, let t) = node {
            #expect(child == childId)
            // Verify transform works
            let result = try t.apply(using: frozen, Value.make(10))
            #expect(result.take(Int.self) == 10)
        } else {
            Issue.record("Expected tryMap case")
        }
    }

    @Test("flatMap stores child and next function")
    func flatMapStoresChildAndNextFunction() {
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

    @Test("sequence stores both children and combine")
    func sequenceStoresBothChildrenAndCombine() {
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
            #expect(result.take(Int.self) == 30)
        } else {
            Issue.record("Expected sequence case")
        }
    }

    @Test("oneOf stores alternatives array")
    func oneOfStoresAlternativesArray() {
        let alternatives = [ID(0), ID(1), ID(2)]
        let node: TestNode = .oneOf(alternatives)

        if case .oneOf(let alts) = node {
            #expect(alts == alternatives)
        } else {
            Issue.record("Expected oneOf case")
        }
    }

    @Test("oneOf with empty alternatives")
    func oneOfWithEmptyAlternatives() {
        let node: TestNode = .oneOf([])

        if case .oneOf(let alts) = node {
            #expect(alts.isEmpty)
        } else {
            Issue.record("Expected oneOf case")
        }
    }

    @Test("many stores child and finalize")
    func manyStoresChildAndFinalize() {
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
            #expect(result.take([Int].self) == [1, 2])
        } else {
            Issue.record("Expected many case")
        }
    }

    @Test("optional stores child, wrapSome, and noneValue")
    func optionalStoresComponents() {
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
            #expect(wrapped.take(Int?.self) == 42)
            // Verify noneValue
            #expect(none.take(Int?.self)! == nil)
        } else {
            Issue.record("Expected optional case")
        }
    }

    @Test("ref stores target ID")
    func refStoresTargetID() {
        let targetId = ID(99)
        let node: TestNode = .ref(targetId)

        if case .ref(let target) = node {
            #expect(target == targetId)
        } else {
            Issue.record("Expected ref case")
        }
    }

    @Test("hole is placeholder")
    func holeIsPlaceholder() {
        let node: TestNode = .hole

        if case .hole = node {
            // Success - hole is a valid case
        } else {
            Issue.record("Expected hole case")
        }
    }

    @Test("Node.ID is Tagged<Tag, Int>")
    func nodeIDIsTagged() {
        let id1 = ID(42)
        let id2 = ID(42)
        let id3 = ID(0)

        #expect(id1 == id2)
        #expect(id1 != id3)
        #expect(id1.rawValue == 42)
    }

    @Test("Node.ID comparison")
    func nodeIDComparison() {
        let id1 = ID(1)
        let id2 = ID(2)
        let id3 = ID(1)

        #expect(id1 == id3)
        #expect(id1 != id2)
    }
}

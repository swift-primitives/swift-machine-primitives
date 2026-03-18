import Testing
@testable import Machine_Primitives

@Suite("Machine.Program")
struct MachineProgramTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>

    enum TestLeaf: Equatable, Sendable {
        case readByte
        case readInt
    }

    enum TestError: Error, Sendable {
        case failed
    }

    typealias TestNode = Machine.Node<TestLeaf, TestError, Mode>
    typealias TestBuilder = Machine.Builder<TestLeaf, TestError, Mode>
    typealias TestProgram = Machine.Program<TestLeaf, TestError, Mode>

    @Test("builder creates empty program")
    func builderCreatesEmptyProgram() {
        var builder = TestBuilder()
        let program = builder.build()
        #expect(program.graph.isEmpty)
    }

    @Test("builder stores maxDepth")
    func builderStoresMaxDepth() {
        var builder = TestBuilder(maxDepth: 100)
        let program = builder.build()
        #expect(program.maxDepth == 100)
    }

    @Test("builder with nil maxDepth")
    func builderWithNilMaxDepth() {
        var builder = TestBuilder(maxDepth: .none)
        let program = builder.build()
        #expect(program.maxDepth == nil)
    }

    @Test("allocate returns unique IDs")
    func allocateReturnsUniqueIDs() {
        var builder = TestBuilder()
        let id0 = builder.allocate(TestNode.hole)
        let id1 = builder.allocate(TestNode.hole)
        let id2 = builder.allocate(TestNode.hole)

        #expect(id0 != id1)
        #expect(id1 != id2)
        #expect(id0 != id2)
    }

    @Test("allocate stores node")
    func allocateStoresNode() {
        var builder = TestBuilder()
        let id = builder.allocate(TestNode.leaf(.readByte))
        let program = builder.build()

        if case .leaf(let leaf) = program[id] {
            #expect(leaf == .readByte)
        } else {
            Issue.record("Expected leaf node")
        }
    }

    @Test("subscript get retrieves correct node")
    func subscriptGetRetrievesCorrectNode() {
        var builder = TestBuilder()
        let id1 = builder.allocate(TestNode.pure(Value.make(42)))
        let id2 = builder.allocate(TestNode.leaf(.readInt))
        let program = builder.build()

        if case .pure(let value) = program[id1] {
            #expect(value[as: Int.self] == 42)
        } else {
            Issue.record("Expected pure node at id1")
        }

        if case .leaf(let leaf) = program[id2] {
            #expect(leaf == .readInt)
        } else {
            Issue.record("Expected leaf node at id2")
        }
    }

    @Test("builder subscript patches hole")
    func builderSubscriptPatchesHole() {
        var builder = TestBuilder()
        let id = builder.allocate(TestNode.hole)

        builder[id] = .leaf(.readByte)
        let program = builder.build()

        if case .leaf(let leaf) = program[id] {
            #expect(leaf == .readByte)
        } else {
            Issue.record("Expected leaf node after modification")
        }
    }

    @Test("count grows with allocations")
    func countGrowsWithAllocations() {
        var builder = TestBuilder()
        let c0 = builder.count

        _ = builder.allocate(TestNode.hole)
        let c1 = builder.count
        #expect(c1 > c0)

        _ = builder.allocate(TestNode.hole)
        let c2 = builder.count
        #expect(c2 > c1)

        _ = builder.allocate(TestNode.hole)
        let c3 = builder.count
        #expect(c3 > c2)
    }

    @Test("program with various node types")
    func programWithVariousNodeTypes() {
        var builder = TestBuilder()

        let pureId = builder.allocate(TestNode.pure(Value.make("test")))
        let leafId = builder.allocate(TestNode.leaf(.readByte))
        let holeId = builder.allocate(TestNode.hole)

        let captureID = builder.captures.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Machine.Transform.Erased<Mode>(capture: captureID)
        let mapId = builder.allocate(TestNode.map(child: pureId, transform: transform))

        let program = builder.build()

        #expect(!program.graph.isEmpty)

        if case .pure = program[pureId] { } else {
            Issue.record("Expected pure at pureId")
        }

        if case .leaf = program[leafId] { } else {
            Issue.record("Expected leaf at leafId")
        }

        if case .hole = program[holeId] { } else {
            Issue.record("Expected hole at holeId")
        }

        if case .map(let child, _) = program[mapId] {
            #expect(child == pureId)
        } else {
            Issue.record("Expected map at mapId")
        }
    }

    @Test("forward reference pattern")
    func forwardReferencePattern() {
        var builder = TestBuilder()

        // Allocate a hole for forward reference
        let recursiveId = builder.allocate(TestNode.hole)

        // Use the ID before filling it in
        let bodyId = builder.allocate(TestNode.ref(recursiveId))

        // Fill in the hole via builder subscript
        builder[recursiveId] = .leaf(.readByte)

        let program = builder.build()

        if case .ref(let target) = program[bodyId] {
            #expect(target == recursiveId)
        } else {
            Issue.record("Expected ref at bodyId")
        }

        if case .leaf = program[recursiveId] { } else {
            Issue.record("Expected leaf at recursiveId after fill")
        }
    }

    @Test("oneOf with multiple alternatives")
    func oneOfWithMultipleAlternatives() {
        var builder = TestBuilder()

        let alt1 = builder.allocate(TestNode.leaf(.readByte))
        let alt2 = builder.allocate(TestNode.leaf(.readInt))
        let alt3 = builder.allocate(TestNode.pure(Value.make(0)))

        let oneOfId = builder.allocate(TestNode.oneOf([alt1, alt2, alt3]))

        let program = builder.build()

        if case .oneOf(let alternatives) = program[oneOfId] {
            #expect(alternatives.count == 3)
            #expect(alternatives[0] == alt1)
            #expect(alternatives[1] == alt2)
            #expect(alternatives[2] == alt3)
        } else {
            Issue.record("Expected oneOf node")
        }
    }

    @Test("sequence node stores both children")
    func sequenceNodeStoresBothChildren() {
        var builder = TestBuilder()

        let first = builder.allocate(TestNode.leaf(.readByte))
        let second = builder.allocate(TestNode.leaf(.readInt))
        let captureID = builder.captures.insert({ (a: Int, b: Int) in (a, b) } as @Sendable (Int, Int) -> (Int, Int))
        let combine = Machine.Combine.Erased<Mode>(capture: captureID)

        let seqId = builder.allocate(TestNode.sequence(a: first, b: second, combine: combine))

        let program = builder.build()

        if case .sequence(let a, let b, _) = program[seqId] {
            #expect(a == first)
            #expect(b == second)
        } else {
            Issue.record("Expected sequence node")
        }
    }

    @Test("many node configuration")
    func manyNodeConfiguration() {
        var builder = TestBuilder()

        let child = builder.allocate(TestNode.leaf(.readByte))
        let finalize = Machine.Finalize.Array<Mode>(elementType: Int.self, store: &builder.captures)

        let manyId = builder.allocate(TestNode.many(child: child, finalize: finalize))

        let program = builder.build()

        if case .many(let childId, _) = program[manyId] {
            #expect(childId == child)
        } else {
            Issue.record("Expected many node")
        }
    }

    @Test("optional node configuration")
    func optionalNodeConfiguration() {
        var builder = TestBuilder()

        let child = builder.allocate(TestNode.leaf(.readByte))
        let captureID = builder.captures.insert({ (x: Int) in x as Int? } as @Sendable (Int) -> Int?)
        let wrapSome = Machine.Transform.Erased<Mode>(capture: captureID)
        let noneValue = Value.make(Int?(nil))

        let optId = builder.allocate(TestNode.optional(child: child, wrapSome: wrapSome, noneValue: noneValue))

        let program = builder.build()

        if case .optional(let childId, _, let none) = program[optId] {
            #expect(childId == child)
            #expect(none[as: Int?.self] == nil)
        } else {
            Issue.record("Expected optional node")
        }
    }
}

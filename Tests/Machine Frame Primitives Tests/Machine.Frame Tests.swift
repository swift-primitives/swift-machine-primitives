import Testing
@testable import Machine_Primitives

// WORKAROUND for a Swift 6.3.1 SILGen crash (signal 5) on
// `store.insert({ ... } as @Sendable (T) throws(E) -> U)`. See
// `swift-institute/Experiments/silgen-sendable-typed-throws-closure-cast/`.
fileprivate extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference {
    mutating func insert<In: Sendable, Out: Sendable, E: Error>(
        _ fn: @Sendable @escaping (In) throws(E) -> Out
    ) -> Machine.Capture.ID<@Sendable (In) throws(E) -> Out> {
        func dispatchToBase<V: Sendable>(_ v: V) -> Machine.Capture.ID<V> { self.insert(v) }
        return dispatchToBase(fn)
    }
}

@Suite("Machine.Frame")
struct MachineFrameTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias Arena = Machine.Value<Mode>.Arena
    typealias NodeID = Int
    typealias Checkpoint = Int
    enum TestError: Error, Sendable { case failed }
    typealias TestFrame = Machine.Frame<NodeID, Checkpoint, Mode, TestError, Never>

    @Test
    func `map stores transform`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Machine.Transform.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let frame: TestFrame = .map(transform: transform)

        if case .map(let t) = frame {
            let result = t.apply(using: frozen, Value.make(21))
            #expect(result[as: Int.self] == 42)
        } else {
            Issue.record("Expected map frame")
        }
    }

    @Test
    func `tryMap stores throwing transform`() throws {
        var store = Store()
        let captureID = store.insert { (x: Int) throws(TestError) -> Int in
            guard x > 0 else { throw .failed }
            return x
        }
        let transform = Machine.Transform.Throwing<Mode, TestError>(capture: captureID)
        let frozen = store.freeze()

        let frame: TestFrame = .tryMap(transform: transform)

        if case .tryMap(let t) = frame {
            let result = try t.apply(using: frozen, Value.make(10))
            #expect(result[as: Int.self] == 10)
        } else {
            Issue.record("Expected tryMap frame")
        }
    }

    @Test
    func `flatMap stores next function`() {
        var store = Store()
        let captureID = store.insert({ (x: Bool) in x ? 1 : 0 } as @Sendable (Bool) -> NodeID)
        let next = Machine.Next.Erased<Mode, NodeID>(capture: captureID)
        let frozen = store.freeze()

        let frame: TestFrame = .flatMap(next: next)

        if case .flatMap(let n) = frame {
            #expect(n.next(using: frozen, Value.make(true)) == 1)
            #expect(n.next(using: frozen, Value.make(false)) == 0)
        } else {
            Issue.record("Expected flatMap frame")
        }
    }

    @Test
    func `sequence stores sequence state`() {
        var store = Store()
        let captureID = store.insert({ (a: Int, b: Int) in a + b } as @Sendable (Int, Int) -> Int)
        let combine = Machine.Combine.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let seqState = Machine.Frame<NodeID, Checkpoint, Mode, TestError, Never>.Sequence.second(b: 5, combine: combine)
        let frame: TestFrame = .sequence(seqState)

        if case .sequence(let state) = frame {
            if case .second(let b, let c) = state {
                #expect(b == 5)
                let result = c.combine(using: frozen, Value.make(10), Value.make(20))
                #expect(result[as: Int.self] == 30)
            } else {
                Issue.record("Expected second state")
            }
        } else {
            Issue.record("Expected sequence frame")
        }
    }

    @Test
    func `oneOf stores alternatives and checkpoint`() {
        let alternatives: [NodeID] = [1, 2, 3, 4]
        let checkpoint: Checkpoint = 100
        let frame: TestFrame = .oneOf(alternatives: alternatives, index: 1, savedCheckpoint: checkpoint)

        if case .oneOf(let alts, let idx, let cp) = frame {
            #expect(alts == [1, 2, 3, 4])
            #expect(idx == 1)
            #expect(cp == 100)
        } else {
            Issue.record("Expected oneOf frame")
        }
    }

    @Test
    func `many stores accumulation state`() {
        var store = Store()
        var arena = Arena()
        let handle1 = arena.allocate(Value.make(1))
        let handle2 = arena.allocate(Value.make(2))

        let finalize = Machine.Finalize.Array<Mode>(elementType: Int.self, store: &store)
        let frozen = store.freeze()

        let frame: TestFrame = .many(
            child: 42,
            savedCheckpoint: 99,
            resultHandles: [handle1, handle2],
            finalize: finalize
        )

        if case .many(let child, let cp, let handles, let f) = frame {
            #expect(child == 42)
            #expect(cp == 99)
            #expect(handles.count == 2)
            let values = handles.map { arena.read($0) }
            let result = f.finalize(using: frozen, values)
            #expect(result[as: [Int].self] == [1, 2])
        } else {
            Issue.record("Expected many frame")
        }
    }

    @Test
    func `optional stores checkpoint and transforms`() {
        var store = Store()
        var arena = Arena()
        let noneHandle = arena.allocate(Value.make(Int?(nil)))
        let captureID = store.insert({ (x: Int) in x as Int? } as @Sendable (Int) -> Int?)
        let wrapSome = Machine.Transform.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let frame: TestFrame = .optional(
            savedCheckpoint: 50,
            wrapSome: wrapSome,
            noneHandle: noneHandle
        )

        if case .optional(let cp, let wrap, let none) = frame {
            #expect(cp == 50)
            let wrapped = wrap.apply(using: frozen, Value.make(42))
            #expect(wrapped[as: Int?.self] == 42)
            #expect(arena.read(none)[as: Int?.self] == nil)
        } else {
            Issue.record("Expected optional frame")
        }
    }

    @Test
    func `recursiveExit is marker`() {
        let frame: TestFrame = .recursiveExit

        if case .recursiveExit = frame {
            // Success
        } else {
            Issue.record("Expected recursiveExit frame")
        }
    }
}

@Suite("Machine.Frame.Sequence")
struct MachineFrameSequenceTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias Arena = Machine.Value<Mode>.Arena
    typealias NodeID = Int

    @Test
    func `second stores node ID and combine`() {
        var store = Store()
        let captureID = store.insert({ (a: String, b: String) in a + b } as @Sendable (String, String) -> String)
        let combine = Machine.Combine.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let seq: Machine.Frame<NodeID, Int, Mode, Never, Never>.Sequence = .second(b: 10, combine: combine)

        if case .second(let b, let c) = seq {
            #expect(b == 10)
            let result = c.combine(using: frozen, Value.make("Hello"), Value.make("World"))
            #expect(result[as: String.self] == "HelloWorld")
        } else {
            Issue.record("Expected second case")
        }
    }

    @Test
    func `combine stores handle and combine function`() {
        var store = Store()
        var arena = Arena()
        let firstHandle = arena.allocate(Value.make(100))
        let captureID = store.insert({ (a: Int, b: Int) in a * b } as @Sendable (Int, Int) -> Int)
        let combine = Machine.Combine.Erased<Mode>(capture: captureID)
        let frozen = store.freeze()

        let seq: Machine.Frame<NodeID, Int, Mode, Never, Never>.Sequence = .combine(
            firstHandle: firstHandle,
            combine: combine
        )

        if case .combine(let handle, let c) = seq {
            #expect(handle == firstHandle)
            let first = arena.read(handle)
            let result = c.combine(using: frozen, first, Value.make(5))
            #expect(result[as: Int.self] == 500)
        } else {
            Issue.record("Expected combine case")
        }
    }
}

@Suite("Machine.Frame with Extra")
struct MachineFrameExtraTests {
    typealias Mode = Machine.Capture.Mode.Reference
    typealias Store = Machine.Capture.Store<Mode>
    typealias Value = Machine.Value<Mode>
    typealias NodeID = Int
    typealias Checkpoint = Int
    enum TestError: Error, Sendable { case failed }

    struct MemoEntry: Equatable, Sendable {
        var nodeId: NodeID
        var position: Int
    }

    typealias FrameWithExtra = Machine.Frame<NodeID, Checkpoint, Mode, TestError, MemoEntry>

    @Test
    func `extra stores custom data`() {
        let memo = MemoEntry(nodeId: 42, position: 100)
        let frame: FrameWithExtra = .extra(memo)

        if case .extra(let entry) = frame {
            #expect(entry.nodeId == 42)
            #expect(entry.position == 100)
        } else {
            Issue.record("Expected extra frame")
        }
    }

    @Test
    func `frame with Extra can still use other cases`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x } as @Sendable (Int) -> Int)
        let transform = Machine.Transform.Erased<Mode>(capture: captureID)
        let frame: FrameWithExtra = .map(transform: transform)

        if case .map = frame {
            // Success
        } else {
            Issue.record("Expected map frame")
        }
    }

    @Test
    func `mixing extra and standard frames`() {
        var store = Store()
        let captureID = store.insert({ (x: Int) in x * 2 } as @Sendable (Int) -> Int)
        let transform = Machine.Transform.Erased<Mode>(capture: captureID)

        var frames: [FrameWithExtra] = []
        frames.append(.map(transform: transform))
        frames.append(.extra(MemoEntry(nodeId: 1, position: 0)))
        frames.append(.recursiveExit)
        frames.append(.extra(MemoEntry(nodeId: 2, position: 10)))

        #expect(frames.count == 4)

        if case .map = frames[0] { } else { Issue.record("Expected map at 0") }
        if case .extra(let e) = frames[1] { #expect(e.nodeId == 1) } else { Issue.record("Expected extra at 1") }
        if case .recursiveExit = frames[2] { } else { Issue.record("Expected recursiveExit at 2") }
        if case .extra(let e) = frames[3] { #expect(e.nodeId == 2) } else { Issue.record("Expected extra at 3") }
    }
}

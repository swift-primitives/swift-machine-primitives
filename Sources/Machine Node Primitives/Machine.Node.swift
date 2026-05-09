public import Graph_Primitives_Core

extension Machine {
    /// A node in the machine's program graph.
    ///
    /// `Node` represents a single operation in a defunctionalized parser program.
    /// It is generic over:
    /// - `Leaf`: The primitive cursor operations (cursor-specific)
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    ///
    /// The machine interpreter traverses the node graph, executing leaf operations
    /// and combining results according to the combinator structure.
    @safe
    public enum Node<Leaf, Failure: Swift.Error, Mode> {

        /// A unique identifier for a node in the program.
        public typealias ID = Graph.Node<Self>

        /// A primitive cursor operation.
        case leaf(Leaf)

        /// A pure value (no cursor interaction).
        case pure(Value<Mode>)

        /// Transform the result of a child node.
        case map(child: ID, transform: Transform.Erased<Mode>)

        /// Transform the result of a child node, potentially failing.
        case tryMap(child: ID, transform: Transform.Throwing<Mode, Failure>)

        /// Execute a child, then select the next node based on its result.
        case flatMap(child: ID, next: Next.Erased<Mode, ID>)

        /// Execute two nodes in sequence, combining their results.
        case sequence(a: ID, b: ID, combine: Combine.Erased<Mode>)

        /// Try alternatives in order until one succeeds.
        case oneOf([ID])

        /// Execute a child zero or more times, collecting results.
        case many(child: ID, finalize: Finalize.Array<Mode>)

        /// Execute a child zero or more times, folding results without allocation.
        ///
        /// Unlike `many` which collects into an array, `fold` accumulates incrementally:
        /// 1. Start with `initial` as accumulator
        /// 2. Try to parse `child`
        /// 3. If success: `accumulator = combine(accumulator, childResult)`, repeat
        /// 4. If failure: return accumulator
        case fold(child: ID, initial: Value<Mode>, combine: Combine.Erased<Mode>)

        /// Execute a child optionally, wrapping success or returning none.
        case optional(child: ID, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

        /// Reference to another node (for recursive grammars).
        case ref(ID)

        /// Placeholder for forward references during construction.
        case hole
    }
}

extension Machine.Node: Sendable
where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}

// MARK: - Graph Adjacency

extension Machine.Node where Leaf: Sendable, Failure: Sendable, Mode: Sendable {
    /// The structurally adjacent node IDs.
    public var adjacent: [ID] {
        switch self {
        case .leaf, .pure, .hole: return []
        case .map(let child, _): return [child]
        case .tryMap(let child, _): return [child]
        case .flatMap(let child, _): return [child]
        case .sequence(let a, let b, _): return [a, b]
        case .oneOf(let ids): return ids
        case .many(let child, _): return [child]
        case .fold(let child, _, _): return [child]
        case .optional(let child, _, _): return [child]
        case .ref(let id): return [id]
        }
    }

    /// Extract closure for graph algorithms.
    public static var extract: Graph.Adjacency.Extract<Self, Self, [ID]> {
        Graph.Adjacency.Extract { $0.adjacent }
    }
}

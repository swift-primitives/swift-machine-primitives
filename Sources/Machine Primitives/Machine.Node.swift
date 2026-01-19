@_exported public import Identity_Primitives

extension Machine {
    /// A node in the machine's program graph.
    ///
    /// `Node` represents a single operation in a defunctionalized parser program.
    /// It is generic over:
    /// - `Leaf`: The primitive cursor operations (cursor-specific)
    /// - `Failure`: The error type for fallible operations
    ///
    /// The machine interpreter traverses the node graph, executing leaf operations
    /// and combining results according to the combinator structure.
    @safe
    public enum Node<Leaf, Failure: Error> {
        /// Phantom type tag for node IDs.
        public enum Tag {}

        /// A unique identifier for a node in the program.
        public typealias ID = Tagged<Tag, Int>

        /// A primitive cursor operation.
        case leaf(Leaf)

        /// A pure value (no cursor interaction).
        case pure(Value)

        /// Transform the result of a child node.
        case map(child: ID, transform: Transform.Erased)

        /// Transform the result of a child node, potentially failing.
        case tryMap(child: ID, transform: Transform.Throwing<Failure>)

        /// Execute a child, then select the next node based on its result.
        case flatMap(child: ID, next: Next.Erased<ID>)

        /// Execute two nodes in sequence, combining their results.
        case sequence(a: ID, b: ID, combine: Combine.Erased)

        /// Try alternatives in order until one succeeds.
        case oneOf([ID])

        /// Execute a child zero or more times, collecting results.
        case many(child: ID, finalize: Finalize.Array)

        /// Execute a child zero or more times, folding results without allocation.
        ///
        /// Unlike `many` which collects into an array, `fold` accumulates incrementally:
        /// 1. Start with `initial` as accumulator
        /// 2. Try to parse `child`
        /// 3. If success: `accumulator = combine(accumulator, childResult)`, repeat
        /// 4. If failure: return accumulator
        case fold(child: ID, initial: Value, combine: Combine.Erased)

        /// Execute a child optionally, wrapping success or returning none.
        case optional(child: ID, wrapSome: Transform.Erased, noneValue: Value)

        /// Reference to another node (for recursive grammars).
        case ref(ID)

        /// Placeholder for forward references during construction.
        case hole

        /// Returns a copy of this node with all IDs offset by the given amount.
        ///
        /// Used when embedding one program into another.
        @inlinable
        public func offset(by delta: Int) -> Self {
            func adjust(_ id: ID) -> ID { ID(id.rawValue + delta) }

            switch self {
            case .leaf(let leaf):
                return .leaf(leaf)
            case .pure(let value):
                return .pure(value)
            case .map(let child, let transform):
                return .map(child: adjust(child), transform: transform)
            case .tryMap(let child, let transform):
                return .tryMap(child: adjust(child), transform: transform)
            case .flatMap(let child, let next):
                let adjustedNext = Next.Erased<ID> { value in
                    adjust(next.next(value))
                }
                return .flatMap(child: adjust(child), next: adjustedNext)
            case .sequence(let a, let b, let combine):
                return .sequence(a: adjust(a), b: adjust(b), combine: combine)
            case .oneOf(let alternatives):
                return .oneOf(alternatives.map(adjust))
            case .many(let child, let finalize):
                return .many(child: adjust(child), finalize: finalize)
            case .fold(let child, let initial, let combine):
                return .fold(child: adjust(child), initial: initial, combine: combine)
            case .optional(let child, let wrapSome, let noneValue):
                return .optional(child: adjust(child), wrapSome: wrapSome, noneValue: noneValue)
            case .ref(let id):
                return .ref(adjust(id))
            case .hole:
                return .hole
            }
        }
    }
}

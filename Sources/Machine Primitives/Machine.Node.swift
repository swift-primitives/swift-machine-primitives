public import Identity_Primitives

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

        /// Execute a child optionally, wrapping success or returning none.
        case optional(child: ID, wrapSome: Transform.Erased, noneValue: Value)

        /// Reference to another node (for recursive grammars).
        case ref(ID)

        /// Placeholder for forward references during construction.
        case hole
    }
}

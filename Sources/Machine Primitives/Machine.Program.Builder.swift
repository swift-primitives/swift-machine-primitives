extension Machine {
    /// A mutable builder for constructing a `Program`.
    ///
    /// `Builder` accumulates nodes and captures during construction,
    /// then produces an immutable `Program` via `build()`.
    public struct Builder<Leaf, Failure: Error, Mode> {
        public var nodes: [Node<Leaf, Failure, Mode>]
        public var captures: Capture.Store<Mode>
        public let maxDepth: Int?

        @inlinable
        public init(maxDepth: Int? = nil) {
            self.nodes = []
            self.captures = Capture.Store<Mode>()
            self.maxDepth = maxDepth
        }

        @inlinable
        public mutating func allocate(_ node: Node<Leaf, Failure, Mode>) -> Node<Leaf, Failure, Mode>.ID {
            let id = Node<Leaf, Failure, Mode>.ID(nodes.count)
            nodes.append(node)
            return id
        }

        @inlinable
        public consuming func build() -> Program<Leaf, Failure, Mode> {
            Program(
                nodes: nodes,
                captures: captures.freeze(),
                maxDepth: maxDepth
            )
        }
    }
}
// Builder is NOT Sendable

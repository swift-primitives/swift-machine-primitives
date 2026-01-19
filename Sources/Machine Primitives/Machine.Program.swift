@_exported public import Identity_Primitives

extension Machine {
    /// A program consisting of a graph of nodes.
    ///
    /// `Program` stores the node graph that represents a defunctionalized parser.
    /// Nodes are allocated sequentially and referenced by their IDs. The program
    /// is generic over:
    /// - `Leaf`: The primitive cursor operations
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    public struct Program<Leaf, Failure: Error, Mode> {
        public let nodes: [Node<Leaf, Failure, Mode>]
        public let captures: Machine.Capture.Frozen<Mode>
        public let maxDepth: Int?

        @usableFromInline
        init(
            nodes: [Node<Leaf, Failure, Mode>],
            captures: Machine.Capture.Frozen<Mode>,
            maxDepth: Int?
        ) {
            self.nodes = nodes
            self.captures = captures
            self.maxDepth = maxDepth
        }

        /// Accesses a node by its ID.
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            nodes[id.rawValue]
        }
    }
}

extension Machine.Program: Sendable
    where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}

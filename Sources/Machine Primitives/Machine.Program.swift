public import Identity_Primitives

extension Machine {
    /// A program consisting of a graph of nodes.
    ///
    /// `Program` stores the node graph that represents a defunctionalized parser.
    /// Nodes are allocated sequentially and referenced by their IDs. The program
    /// is generic over:
    /// - `Leaf`: The primitive cursor operations
    /// - `Failure`: The error type for fallible operations
    public struct Program<Leaf, Failure: Error> {
        public var nodes: [Node<Leaf, Failure>]

        public let maxDepth: Int?

        @inlinable
        public init(maxDepth: Int? = nil) {
            self.nodes = []
            self.maxDepth = maxDepth
        }

        /// Allocates a new node in the program and returns its ID.
        @inlinable
        public mutating func allocate(_ node: Node<Leaf, Failure>) -> Node<Leaf, Failure>.ID {
            let id = Node<Leaf, Failure>.ID(nodes.count)
            nodes.append(node)
            return id
        }

        /// Accesses a node by its ID.
        @inlinable
        public subscript(id: Node<Leaf, Failure>.ID) -> Node<Leaf, Failure> {
            get { nodes[id.rawValue] }
            set { nodes[id.rawValue] = newValue }
        }
    }
}

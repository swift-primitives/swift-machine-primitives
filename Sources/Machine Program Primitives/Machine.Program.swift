// SDG(specializes): Machine.Program is a directed graph with Graph.Sequential storage
public import Graph_Sequential_Primitives

extension Machine {
    /// A program consisting of a graph of nodes.
    ///
    /// `Program` stores the node graph that represents a defunctionalized parser.
    /// Nodes are allocated sequentially and referenced by their IDs. The program
    /// is generic over:
    /// - `Leaf`: The primitive cursor operations
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    public struct Program<Leaf, Failure: Swift.Error, Mode> {
        public let graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>
        public let captures: Machine.Capture.Frozen<Mode>
        public let maxDepth: Int?

        @usableFromInline
        init(
            graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>,
            captures: Machine.Capture.Frozen<Mode>,
            maxDepth: Int?
        ) {
            self.graph = graph
            self.captures = captures
            self.maxDepth = maxDepth
        }

        /// Accesses a node by its ID.
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            graph[id]
        }

        /// Analysis accessor for graph algorithms.
        @inlinable
        public var analyze: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Analyze<[Node<Leaf, Failure, Mode>.ID]> {
            graph.analyze(using: Node.extract)
        }
    }
}

extension Machine.Program: Sendable where Leaf: Sendable, Mode: Sendable {}

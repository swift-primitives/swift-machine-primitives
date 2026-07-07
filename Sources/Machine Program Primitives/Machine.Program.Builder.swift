public import Graph_Sequential_Primitives

extension Machine {
    /// A mutable builder for constructing a `Program`.
    ///
    /// `Builder` accumulates nodes and captures during construction,
    /// then produces an immutable `Program` via `build()`.
    public struct Builder<Leaf, Failure: Swift.Error, Mode>: ~Copyable {
        @usableFromInline
        var storage: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Builder

        /// The mutable capture store accumulated alongside the node graph.
        public var captures: Capture.Store<Mode>

        /// Optional maximum machine-stack depth enforced at run time.
        public let maxDepth: Int?

        /// Creates an empty builder, optionally bounding the machine-stack depth.
        @inlinable
        public init(maxDepth: Int? = nil) {
            self.storage = .init()
            self.captures = Capture.Store<Mode>()
            self.maxDepth = maxDepth
        }

        /// The number of nodes allocated so far.
        @inlinable
        public var count: Node<Leaf, Failure, Mode>.ID.Count {
            storage.count
        }

        /// Appends a node to the program graph, returning its ID.
        @inlinable
        public mutating func allocate(_ node: Node<Leaf, Failure, Mode>) -> Node<Leaf, Failure, Mode>.ID {
            storage.allocate(node)
        }

        /// Access/patch a node by ID (for hole patching).
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            get { storage[id] }
            set { storage[id] = newValue }
        }

        /// Consumes the builder, producing the immutable program.
        @inlinable
        public consuming func build() -> Program<Leaf, Failure, Mode> {
            Program(
                graph: storage.build(),
                captures: captures.freeze(),
                maxDepth: maxDepth
            )
        }
    }
}
// Builder is NOT Sendable

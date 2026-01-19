extension Machine.Next {
    /// A type-erased next-node selection function for flatMap.
    ///
    /// Given a value, selects the next node ID to execute, enabling
    /// cursor-agnostic flatMap operations in the machine.
    @safe
    public struct Erased<NodeID> {
        public let next: (Machine.Value) -> NodeID

        @inlinable
        public init<In>(_ nextFn: @escaping (In) -> NodeID) {
            self.next = { value in
                let input = value.unsafeTake(In.self)
                return nextFn(input)
            }
        }
    }
}

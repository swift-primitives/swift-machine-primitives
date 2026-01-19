extension Machine.Combine {
    /// A type-erased binary combination operation.
    ///
    /// Combines two values into a single result value, used for
    /// sequence operations in the machine.
    @safe
    public struct Erased {
        public let combine: (Machine.Value, Machine.Value) -> Machine.Value

        @inlinable
        public init<A, B, Out>(_ combineFn: @escaping (A, B) -> Out) {
            self.combine = { a, b in
                let aVal = a.unsafeTake(A.self)
                let bVal = b.unsafeTake(B.self)
                return Machine.Value.make(combineFn(aVal, bVal))
            }
        }
    }
}

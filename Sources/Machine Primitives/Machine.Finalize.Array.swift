extension Machine.Finalize {
    /// A type-erased array finalization operation.
    ///
    /// Converts a collection of values into a single typed array value,
    /// used for the `many` combinator.
    @safe
    public struct Array {
        public let finalize: ([Machine.Value]) -> Machine.Value

        @inlinable
        public init<T>(_ elementType: T.Type) {
            self.finalize = { values in
                Machine.Value.make(values.map { $0.unsafeTake(T.self) })
            }
        }
    }
}

extension Machine.Transform {
    /// A type-erased throwing transformation from one value to another.
    ///
    /// Generic over `Failure` to support both generic error types (Parsing)
    /// and fixed error types (Binary's `Fault`).
    @safe
    public struct Throwing<Failure: Error> {
        public let apply: (Machine.Value) throws(Failure) -> Machine.Value

        @inlinable
        public init<In, Out>(_ transform: @escaping (In) throws(Failure) -> Out) {
            self.apply = { (value: Machine.Value) throws(Failure) -> Machine.Value in
                let input = value.unsafeTake(In.self)
                return Machine.Value.make(try transform(input))
            }
        }
    }
}

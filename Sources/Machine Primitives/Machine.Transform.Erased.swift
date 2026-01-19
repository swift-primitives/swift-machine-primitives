extension Machine.Transform {
    /// A type-erased non-throwing transformation from one value to another.
    @safe
    public struct Erased {
        public let apply: (Machine.Value) -> Machine.Value

        @inlinable
        public init<In, Out>(_ transform: @escaping (In) -> Out) {
            self.apply = { value in
                let input = value.unsafeTake(In.self)
                return Machine.Value.make(transform(input))
            }
        }
    }
}

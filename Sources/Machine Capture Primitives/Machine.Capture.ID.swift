extension Machine.Capture {
    /// A typed handle to a captured value of type `Value` in a capture store.
    public struct ID<Value>: Hashable, Sendable {
        /// The untyped slot identifier this typed handle wraps.
        public let raw: RawID

        @usableFromInline
        init(_ raw: RawID) {
            self.raw = raw
        }

        /// The underlying slot index.
        @inlinable
        public var rawValue: Int { raw.rawValue }
    }
}

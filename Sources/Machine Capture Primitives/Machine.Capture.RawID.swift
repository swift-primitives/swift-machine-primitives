extension Machine.Capture {
    /// An untyped slot identifier into a capture store.
    public struct RawID: Hashable, Sendable {
        /// The underlying slot index.
        public let rawValue: Int

        @usableFromInline
        init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

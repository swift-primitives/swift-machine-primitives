extension Machine.Capture {
    /// Mutable storage for captured values during program construction.
    ///
    /// `Store<Mode>` accumulates type-erased values that will be used by
    /// the machine at runtime. Call `freeze()` to produce an immutable
    /// `Frozen<Mode>` for use with the final `Program`.
    ///
    /// ## Mode
    ///
    /// - `Mode.Reference`: `insert` requires `T: Sendable`
    /// - `Mode.Unchecked`: `insert` accepts any `T`
    public struct Store<Mode> {
        @usableFromInline
        var slots: [Slot]

        @inlinable
        public init() {
            self.slots = []
        }

        /// Freezes the store into an immutable `Frozen` for program execution.
        @inlinable
        public consuming func freeze() -> Frozen<Mode> {
            Frozen(__slots: slots)
        }
    }
}

extension Machine.Frame {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// Sequence continuation state within a frame.
    ///
    /// Tracks progress through a two-element sequence operation.
    @safe
    public enum Sequence {
        /// Waiting to execute the second child.
        case second(b: NodeID, combine: Machine.Combine.Erased<Mode>)

        /// Stores handle to first value in arena, waiting for second value.
        case combine(firstHandle: Machine.Value<Mode>.Handle, combine: Machine.Combine.Erased<Mode>)
    }
}

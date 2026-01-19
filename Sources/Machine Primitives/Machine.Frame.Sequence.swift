extension Machine.Frame {
    /// Sequence continuation state within a frame.
    ///
    /// Tracks progress through a two-element sequence operation.
    @safe
    public enum Sequence {
        /// Waiting to execute the second child.
        case second(b: NodeID, combine: Machine.Combine.Erased)

        /// Stores handle to first value in arena, waiting for second value.
        case combine(firstHandle: Machine.Value.Handle, combine: Machine.Combine.Erased)
    }
}

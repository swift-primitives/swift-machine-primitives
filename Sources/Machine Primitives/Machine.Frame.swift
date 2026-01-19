extension Machine {
    /// A stack frame in the machine's execution.
    ///
    /// `Frame` represents the continuation state when the machine enters
    /// a child node. It is generic over:
    /// - `NodeID`: The node identifier type
    /// - `Checkpoint`: The cursor checkpoint type (varies by cursor)
    /// - `Failure`: The error type for fallible operations
    /// - `Extra`: Extension point for façade-specific frame types (use `Never` if not needed)
    @safe
    public enum Frame<NodeID, Checkpoint, Failure: Error, Extra> {
        /// Apply a non-throwing transform to the result.
        case map(transform: Transform.Erased)

        /// Apply a throwing transform to the result.
        case tryMap(transform: Transform.Throwing<Failure>)

        /// Select the next node based on the result.
        case flatMap(next: Next.Erased<NodeID>)

        /// Sequence continuation state.
        case sequence(Sequence)

        /// Backtracking frame for oneOf - stores checkpoint instead of full input copy.
        case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)

        /// Accumulation frame for many - stores handles to accumulated results.
        case many(child: NodeID, savedCheckpoint: Checkpoint, resultHandles: [Value.Handle], finalize: Finalize.Array)

        /// Fold frame - accumulates without allocation using combine function.
        case fold(child: NodeID, savedCheckpoint: Checkpoint, accumulatorHandle: Value.Handle, combine: Combine.Erased)

        /// Optional frame - stores handle to none value for backtracking.
        case optional(savedCheckpoint: Checkpoint, wrapSome: Transform.Erased, noneHandle: Value.Handle)

        /// Marker for recursive call return.
        case recursiveExit

        /// Extension point for façade-specific frames.
        ///
        /// Use `Extra = Never` when no additional frame types are needed (the case becomes uninhabited).
        /// Parsing uses this for memoization: `Extra = Frame.Extra` with `.memoization(node:startPosition:)`.
        case extra(Extra)
    }
}

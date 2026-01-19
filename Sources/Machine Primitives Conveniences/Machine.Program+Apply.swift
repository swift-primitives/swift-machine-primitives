public import Machine_Primitives

// MARK: - Program Apply Conveniences

extension Machine.Program {
    // MARK: Transform.Erased

    /// Applies a transform using this program's frozen captures.
    ///
    /// Convenience for `transform.apply(using: captures, value)`.
    @inlinable
    public func apply(
        _ transform: Machine.Transform.Erased<Mode>,
        to value: Machine.Value<Mode>
    ) -> Machine.Value<Mode> {
        transform.apply(using: captures, value)
    }

    // MARK: Transform.Throwing

    /// Applies a throwing transform using this program's frozen captures.
    ///
    /// Convenience for `transform.apply(using: captures, value)`.
    @inlinable
    public func apply(
        _ transform: Machine.Transform.Throwing<Mode, Failure>,
        to value: Machine.Value<Mode>
    ) throws(Failure) -> Machine.Value<Mode> {
        try transform.apply(using: captures, value)
    }

    // MARK: Combine.Erased

    /// Combines two values using this program's frozen captures.
    ///
    /// Convenience for `combine.combine(using: captures, a, b)`.
    @inlinable
    public func combine(
        _ combine: Machine.Combine.Erased<Mode>,
        _ a: Machine.Value<Mode>,
        _ b: Machine.Value<Mode>
    ) -> Machine.Value<Mode> {
        combine.combine(using: captures, a, b)
    }

    // MARK: Next.Erased

    /// Selects the next node using this program's frozen captures.
    ///
    /// Convenience for `next.next(using: captures, value)`.
    @inlinable
    public func next(
        _ next: Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID>,
        from value: Machine.Value<Mode>
    ) -> Machine.Node<Leaf, Failure, Mode>.ID {
        next.next(using: captures, value)
    }

    // MARK: Finalize.Array

    /// Finalizes an array of values using this program's frozen captures.
    ///
    /// Convenience for `finalize.finalize(using: captures, values)`.
    @inlinable
    public func finalize(
        _ finalize: Machine.Finalize.Array<Mode>,
        _ values: [Machine.Value<Mode>]
    ) -> Machine.Value<Mode> {
        finalize.finalize(using: captures, values)
    }
}

public import Machine_Primitives

// MARK: - Builder Carrier Factory Conveniences (Reference Mode)

extension Machine.Builder where Mode == Machine.Capture.Mode.Reference {
    // MARK: Transform.Erased

    /// Creates a type-erased transform by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let transform = Transform.Erased<Mode>(capture: captureID)
    /// ```
    @inlinable
    public mutating func transform<In, Out: Sendable>(
        _ fn: @escaping @Sendable (In) -> Out
    ) -> Machine.Transform.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Erased<Mode>(capture: captureID)
    }

    // MARK: Transform.Throwing

    /// Creates a type-erased throwing transform by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let transform = Transform.Throwing<Mode, Failure>(capture: captureID)
    /// ```
    @inlinable
    public mutating func throwingTransform<In, Out: Sendable>(
        _ fn: @escaping @Sendable (In) throws(Failure) -> Out
    ) -> Machine.Transform.Throwing<Mode, Failure> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Throwing<Mode, Failure>(capture: captureID)
    }

    // MARK: Combine.Erased

    /// Creates a type-erased combine by capturing a binary closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let combine = Combine.Erased<Mode>(capture: captureID)
    /// ```
    @inlinable
    public mutating func combine<A, B, Out: Sendable>(
        _ fn: @escaping @Sendable (A, B) -> Out
    ) -> Machine.Combine.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Combine.Erased<Mode>(capture: captureID)
    }

    // MARK: Next.Erased

    /// Creates a type-erased next selector by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let next = Next.Erased<Mode, NodeID>(capture: captureID)
    /// ```
    @inlinable
    public mutating func next<In>(
        _ fn: @escaping @Sendable (In) -> Machine.Node<Leaf, Failure, Mode>.ID
    ) -> Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID> {
        let captureID = captures.insert(fn)
        return Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID>(capture: captureID)
    }

    // MARK: Finalize.Array

    /// Creates a type-erased array finalizer for a given element type.
    ///
    /// Convenience for:
    /// ```swift
    /// let finalize = Finalize.Array<Mode>(elementType: T.self, store: &builder.captures)
    /// ```
    @inlinable
    public mutating func finalize<T: Sendable>(
        elementType: T.Type
    ) -> Machine.Finalize.Array<Mode> {
        Machine.Finalize.Array<Mode>(elementType: T.self, store: &captures)
    }
}

// MARK: - Builder Carrier Factory Conveniences (Unchecked Mode)

extension Machine.Builder where Mode == Machine.Capture.Mode.Unchecked {
    // MARK: Transform.Erased

    /// Creates a type-erased transform by capturing a closure (unchecked mode).
    @inlinable
    public mutating func transform<In, Out>(
        _ fn: @escaping (In) -> Out
    ) -> Machine.Transform.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Erased<Mode>(capture: captureID)
    }

    // MARK: Transform.Throwing

    /// Creates a type-erased throwing transform by capturing a closure (unchecked mode).
    @inlinable
    public mutating func throwingTransform<In, Out>(
        _ fn: @escaping (In) throws(Failure) -> Out
    ) -> Machine.Transform.Throwing<Mode, Failure> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Throwing<Mode, Failure>(capture: captureID)
    }

    // MARK: Combine.Erased

    /// Creates a type-erased combine by capturing a binary closure (unchecked mode).
    @inlinable
    public mutating func combine<A, B, Out>(
        _ fn: @escaping (A, B) -> Out
    ) -> Machine.Combine.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Combine.Erased<Mode>(capture: captureID)
    }

    // MARK: Next.Erased

    /// Creates a type-erased next selector by capturing a closure (unchecked mode).
    @inlinable
    public mutating func next<In>(
        _ fn: @escaping (In) -> Machine.Node<Leaf, Failure, Mode>.ID
    ) -> Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID> {
        let captureID = captures.insert(fn)
        return Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID>(capture: captureID)
    }

    // MARK: Finalize.Array

    /// Creates a type-erased array finalizer for a given element type (unchecked mode).
    @inlinable
    public mutating func finalize<T>(
        elementType: T.Type
    ) -> Machine.Finalize.Array<Mode> {
        Machine.Finalize.Array<Mode>(elementType: T.self, store: &captures)
    }
}

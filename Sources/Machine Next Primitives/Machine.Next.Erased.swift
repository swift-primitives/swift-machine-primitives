extension Machine.Next {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased next-node selection function for flatMap.
    ///
    /// Given a value, selects the next node ID to execute, enabling
    /// cursor-agnostic flatMap operations in the machine.
    @safe
    public struct Erased<Mode, NodeID>: Sendable {
        /// The capture slot holding the underlying typed selection function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _next:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) -> NodeID

        /// Selects the next node ID for the given value using the frozen captures.
        @inlinable
        public func next(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) -> NodeID {
            _next(captures, value)
        }
    }
}

extension Machine.Next.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased selector from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In>(
        capture: Machine.Capture.ID<@Sendable (In) -> NodeID>
    ) where NodeID: Sendable {
        let raw = capture.raw
        self.capture = raw
        self._next = { captures, value in
            captures.withRaw(raw, as: (@Sendable (In) -> NodeID).self) { nextFn in
                nextFn(value[as: In.self])
            }
        }
    }
}

extension Machine.Next.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased selector from a captured typed function (Unchecked mode).
    @inlinable
    public init<In>(
        capture: Machine.Capture.ID<(In) -> NodeID>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._next = { captures, value in
            captures.withRaw(raw, as: ((In) -> NodeID).self) { nextFn in
                nextFn(value[as: In.self])
            }
        }
    }
}

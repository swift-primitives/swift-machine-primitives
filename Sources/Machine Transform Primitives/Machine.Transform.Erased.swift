extension Machine.Transform {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased non-throwing transformation from one value to another.
    @safe
    public struct Erased<Mode>: Sendable {
        /// The capture slot holding the underlying typed transform.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

        /// Applies the transform to the given value using the frozen captures.
        @inlinable
        public func apply(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) -> Machine.Value<Mode> {
            _apply(captures, value)
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased transform from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: (@Sendable (In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased transform from a captured typed function (Unchecked mode).
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: ((In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}

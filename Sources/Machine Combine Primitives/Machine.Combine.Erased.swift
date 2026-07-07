extension Machine.Combine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased binary combination operation.
    ///
    /// Combines two values into a single result value, used for
    /// sequence operations in the machine.
    @safe
    public struct Erased<Mode>: Sendable {
        /// The capture slot holding the underlying typed combine function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _combine:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

        /// Combines two values into one using the frozen captures.
        @inlinable
        public func combine(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ a: Machine.Value<Mode>,
            _ b: Machine.Value<Mode>
        ) -> Machine.Value<Mode> {
            _combine(captures, a, b)
        }
    }
}

extension Machine.Combine.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased combine from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<A, B, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (A, B) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._combine = { captures, a, b in
            captures.withRaw(raw, as: (@Sendable (A, B) -> Out).self) { combineFn in
                a.combine(b, using: combineFn)
            }
        }
    }
}

extension Machine.Combine.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased combine from a captured typed function (Unchecked mode).
    @inlinable
    public init<A, B, Out>(
        capture: Machine.Capture.ID<(A, B) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._combine = { captures, a, b in
            captures.withRaw(raw, as: ((A, B) -> Out).self) { combineFn in
                a.combine(b, using: combineFn)
            }
        }
    }
}

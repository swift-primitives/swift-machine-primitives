extension Machine.Combine {
    /// A type-erased binary combination operation.
    ///
    /// Combines two values into a single result value, used for
    /// sequence operations in the machine.
    @safe
    public struct Erased<Mode>: Sendable {
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _combine:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

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

extension Machine.Finalize {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased array finalization operation.
    ///
    /// Converts a collection of values into a single typed array value,
    /// used for the `many` combinator.
    @safe
    public struct Array<Mode>: Sendable {
        /// The capture slot holding the underlying typed finalize function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _finalize:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                [Machine.Value<Mode>]
            ) -> Machine.Value<Mode>

        /// Converts the collected values into a single typed array value.
        @inlinable
        public func finalize(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ values: [Machine.Value<Mode>]
        ) -> Machine.Value<Mode> {
            _finalize(captures, values)
        }
    }
}

extension Machine.Finalize.Array where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased finalizer from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<T: Sendable>(
        capture: Machine.Capture.ID<@Sendable ([Machine.Value<Mode>]) -> [T]>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._finalize = { captures, values in
            captures.withRaw(raw, as: (@Sendable ([Machine.Value<Mode>]) -> [T]).self) { finalizeFn in
                Machine.Value<Mode>.make(finalizeFn(values))
            }
        }
    }

    /// Creates and captures a finalizer that extracts `[T]` from the erased values (Reference mode).
    @inlinable
    public init<T: Sendable>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0[as: T.self] }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

extension Machine.Finalize.Array where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased finalizer from a captured typed function (Unchecked mode).
    @inlinable
    public init<T>(
        capture: Machine.Capture.ID<([Machine.Value<Mode>]) -> [T]>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._finalize = { captures, values in
            captures.withRaw(raw, as: (([Machine.Value<Mode>]) -> [T]).self) { finalizeFn in
                Machine.Value<Mode>.make(finalizeFn(values))
            }
        }
    }

    /// Creates and captures a finalizer that extracts `[T]` from the erased values (Unchecked mode).
    @inlinable
    public init<T>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0[as: T.self] }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

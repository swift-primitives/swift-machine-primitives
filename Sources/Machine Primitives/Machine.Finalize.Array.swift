extension Machine.Finalize {
    /// A type-erased array finalization operation.
    ///
    /// Converts a collection of values into a single typed array value,
    /// used for the `many` combinator.
    @safe
    public struct Array<Mode>: Sendable {
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _finalize: @Sendable (
            borrowing Machine.Capture.Frozen<Mode>,
            [Machine.Value<Mode>]
        ) -> Machine.Value<Mode>

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

    @inlinable
    public init<T: Sendable>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0.unsafeTake(T.self) }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

extension Machine.Finalize.Array where Mode == Machine.Capture.Mode.Unchecked {
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

    @inlinable
    public init<T>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0.unsafeTake(T.self) }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

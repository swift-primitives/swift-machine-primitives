extension Machine.Transform {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased throwing transformation from one value to another.
    ///
    /// Generic over `Failure` to support both generic error types (Parsing)
    /// and fixed error types (Binary's `Fault`).
    @safe
    public struct Throwing<Mode, Failure: Swift.Error>: Sendable {
        /// The capture slot holding the underlying typed throwing transform.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) throws(Failure) -> Machine.Value<Mode>

        /// Applies the throwing transform to the given value using the frozen captures.
        @inlinable
        public func apply(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) throws(Failure) -> Machine.Value<Mode> {
            try _apply(captures, value)
        }
    }
}

extension Machine.Transform.Throwing where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased throwing transform from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing
        // WHY: Compiler crashes (signal 11) with nested typed throws closures
        // WHY: when withRawThrowing's body closure annotates throws(Failure).
        // WHEN TO REMOVE: When the Swift compiler supports nested typed throws
        // WHEN TO REMOVE: in closure contexts without crashing.
        // TRACKING: swift-institute/Research/swift-compiler-bug-catalog.md
        // TRACKING: (nested typed-throws closure crash — candidate entry).
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read((@Sendable (In) throws(Failure) -> Out).self)
            return try value.apply(transform)
        }
    }
}

extension Machine.Transform.Throwing where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased throwing transform from a captured typed function (Unchecked mode).
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing (see Reference init above)
        // WHY: Compiler crashes (signal 11) with nested typed throws closures
        // WHY: when withRawThrowing's body closure annotates throws(Failure).
        // WHEN TO REMOVE: When the Swift compiler supports nested typed throws
        // WHEN TO REMOVE: in closure contexts without crashing.
        // TRACKING: swift-institute/Research/swift-compiler-bug-catalog.md
        // TRACKING: (nested typed-throws closure crash — candidate entry).
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read(((In) throws(Failure) -> Out).self)
            return try value.apply(transform)
        }
    }
}

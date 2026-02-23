extension Machine.Transform {
    /// A type-erased throwing transformation from one value to another.
    ///
    /// Generic over `Failure` to support both generic error types (Parsing)
    /// and fixed error types (Binary's `Fault`).
    @safe
    public struct Throwing<Mode, Failure: Error>: Sendable {
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply: @Sendable (
            borrowing Machine.Capture.Frozen<Mode>,
            Machine.Value<Mode>
        ) throws(Failure) -> Machine.Value<Mode>

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
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing
        // WHY: Compiler crashes (signal 11) with nested typed throws closures
        //      when withRawThrowing's body closure annotates throws(Failure).
        // WHEN TO REMOVE: When the Swift compiler supports nested typed throws
        //      in closure contexts without crashing.
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read((@Sendable (In) throws(Failure) -> Out).self)
            let input = value.unsafeTake(In.self)
            return Machine.Value<Mode>.make(try transform(input))
        }
    }
}

extension Machine.Transform.Throwing where Mode == Machine.Capture.Mode.Unchecked {
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing (see Reference init above)
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read(((In) throws(Failure) -> Out).self)
            let input = value.unsafeTake(In.self)
            return Machine.Value<Mode>.make(try transform(input))
        }
    }
}

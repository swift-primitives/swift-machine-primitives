extension Machine.Capture.Frozen where Mode == Machine.Capture.Mode.Reference {
    /// Accesses a captured value by its typed ID.
    @inlinable
    public func with<Value: Sendable, R>(
        _ id: Machine.Capture.ID<Value>,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[id.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with explicit type.
    public func withRaw<Value: Sendable, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    public func withRawThrowing<Value: Sendable, R, E: Swift.Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}

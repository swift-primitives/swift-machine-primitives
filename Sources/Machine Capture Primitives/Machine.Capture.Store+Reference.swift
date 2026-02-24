extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference {
    /// Inserts a Sendable value and returns a typed capture ID.
    ///
    /// The Sendable constraint ensures all values in Reference mode are safe
    /// to share across isolation domains.
    @inlinable
    public mutating func insert<Value: Sendable>(_ value: Value) -> Machine.Capture.ID<Value> {
        let raw = Machine.Capture.RawID(slots.count)
        slots.append(Machine.Capture.Slot(value))
        return Machine.Capture.ID<Value>(raw)
    }

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
    @usableFromInline
    func withRaw<Value: Sendable, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    @usableFromInline
    func withRawThrowing<Value: Sendable, R, E: Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}

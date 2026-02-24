extension Machine {
    /// A type-erased value container for the machine's runtime.
    ///
    /// `Value` stores any type-erased value during machine execution, preserving
    /// the original type information via `ObjectIdentifier` for safe extraction.
    ///
    /// ## No Existentials
    ///
    /// This type uses table-based storage to avoid existential types (`AnyObject`,
    /// `Any`, `as?` casts). The internal `_Storage` class holds an opaque pointer
    /// and a `_Table` with type-specialized operations. Extraction loads directly
    /// from the pointer after verifying the type via `ObjectIdentifier`.
    ///
    /// ## Sendable
    ///
    /// `Value<Mode>` is Sendable when `Mode: Sendable`. For `Mode.Reference`,
    /// values can only be constructed from Sendable payloads via `make<T: Sendable>`,
    /// ensuring the Sendable conformance is structurally sound without `@unchecked`
    /// on `Value` itself.
    ///
    /// ## Construction
    ///
    /// The only public construction paths are:
    /// - `Value<Mode.Reference>.make<T: Sendable>(_:)` - requires Sendable payload
    /// - `Value<Mode.Unchecked>.make<T>(_:)` - no Sendable requirement
    @safe
    public struct Value<Mode> {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let storage: _Storage

        /// Reference-counted storage with type-specialized destruction.
        ///
        /// This is NOT `AnyObject`—it's a concrete class type. No `as?` casting
        /// is needed to access the payload.
        ///
        /// ## Sendable
        ///
        /// `_Storage` is `@unchecked Sendable` because:
        /// - `payload` pointer is immutable after construction
        /// - `table` is Sendable (contains only @Sendable function)
        /// - The pointee is immutable (value stored at construction, never mutated)
        /// - `deinit` is called exactly once when refcount hits zero
        ///
        /// This is the ONLY `@unchecked Sendable` in `Machine.Value`. The outer
        /// `Value<Mode>` derives Sendable from `Mode: Sendable` without `@unchecked`.
        @usableFromInline
        final class _Storage: @unchecked Sendable {
            @usableFromInline
            let payload: UnsafeMutableRawPointer

            @usableFromInline
            let table: _Table

            @usableFromInline
            init(payload: UnsafeMutableRawPointer, table: _Table) {
                self.payload = payload
                self.table = table
            }

            deinit {
                table.destroy(payload)
            }
        }

        /// Table of type-specialized operations.
        ///
        /// The `destroy` function captures only type metadata (`T`'s layout),
        /// not user-provided runtime values. This is acceptable for Embedded
        /// compatibility as it's equivalent to generic specialization—no closure
        /// context with user data, only compiler-generated type information.
        @usableFromInline
        struct _Table: Sendable {
            /// Destroys and deallocates the payload.
            /// Specialized for `T` at construction time.
            @usableFromInline
            let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

            @usableFromInline
            init<T>(_: T.Type) {
                self.destroy = { raw in
                    raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    raw.deallocate()
                }
            }
        }

        @usableFromInline
        init(type: ObjectIdentifier, storage: _Storage) {
            self.type = type
            self.storage = storage
        }

        /// Single choke-point for payload projection.
        ///
        /// All `assumingMemoryBound` calls go through here, making the
        /// unsafe binding structurally tied to the stored type id.
        ///
        /// - Precondition: `T` must match the type used at construction.
        @usableFromInline
        func _project<T>(_: T.Type) -> UnsafePointer<T> {
            UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
        }

        /// Attempts to extract the value as the specified type.
        ///
        /// Returns `nil` if the type does not match.
        @inlinable
        public func take<T>(_ expectedType: T.Type) -> T? {
            guard type == ObjectIdentifier(T.self) else {
                return nil
            }
            return _project(T.self).pointee
        }

        /// Precondition-checked type projection.
        ///
        /// Reads the stored value after verifying the type matches via `ObjectIdentifier`.
        /// Named to align with `Capture.Slot.read(_:)` which performs the identical operation.
        ///
        /// - Precondition: The value must have been created with the same type `T`.
        public func read<T>(_ expectedType: T.Type) -> T {
            precondition(
                type == ObjectIdentifier(T.self),
                "Machine.Value type mismatch: expected \(T.self), got type with id \(type)"
            )
            return _project(T.self).pointee
        }
    }
}

// MARK: - Reference Mode Value Operations

extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(read(In.self)))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable, E: Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(read(In.self)))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out: Sendable>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(read(A.self), other.read(B.self)))
    }
}

// MARK: - Unchecked Mode Value Operations

extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(read(In.self)))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out, E: Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(read(In.self)))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(read(A.self), other.read(B.self)))
    }
}

// MARK: - Reference Mode Construction

extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Creates a type-erased value from a concrete Sendable value.
    ///
    /// This is the only construction path for `Value<Mode.Reference>`.
    /// The Sendable constraint ensures all values in Reference mode are safe
    /// to share across isolation domains.
    @inlinable
    public static func make<T: Sendable>(_ value: T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Machine.Value<Mode>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Unchecked Mode Construction

extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates a type-erased value from a concrete value.
    ///
    /// This is the only construction path for `Value<Mode.Unchecked>`.
    /// No Sendable constraint—use this mode when Sendable is not required.
    @inlinable
    public static func make<T>(_ value: T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Machine.Value<Mode>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Sendable Conformance

extension Machine.Value: Sendable where Mode: Sendable {}

extension Machine {
    /// A type-erased value container for the machine's runtime.
    ///
    /// `Value` stores any type-erased value during machine execution, preserving
    /// the original type information via `ObjectIdentifier` for safe extraction.
    /// Supports both `Copyable` and `~Copyable` payloads.
    ///
    /// ## No Existentials
    ///
    /// This type uses table-based storage to avoid existential types (`AnyObject`,
    /// `Any`, `as?` casts). The internal `_Storage` class holds an opaque pointer
    /// and a `_Table` with type-specialized operations. Access is via `_read`
    /// subscript (borrow) or `~Escapable` `Ref` (lifetime-dependent borrow).
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
    /// - `Value<Mode.Reference>.make<T: Sendable & ~Copyable>(_:)` - requires Sendable payload
    /// - `Value<Mode.Unchecked>.make<T: ~Copyable>(_:)` - no Sendable requirement
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
        // WHY: Category D — structural Sendable workaround (SP-7) per [MEM-SAFE-024].
        // WHY: Immutable `let payload: UnsafeMutableRawPointer` + `let table: _Table`
        // WHY: after construction. UnsafeMutableRawPointer blocks structural inference.
        // WHY: No synchronization, no ~Copyable. Pointee is never mutated.
        // WHY: Encapsulation invariant per [MEM-SAFE-021] — `_Storage` is `@usableFromInline`
        // WHY: but its raw-pointer storage is internal-only; consumers see only the
        // WHY: type-safe `Value` surface.
        // WHEN TO REMOVE: When compiler gains structural Sendable through raw pointers.
        // TRACKING: unsafe-audit-findings.md Category D SP-7.
        @usableFromInline
        final class _Storage: @unchecked Sendable {
            @usableFromInline
            let payload: UnsafeMutableRawPointer

            @usableFromInline
            let table: _Table

            @usableFromInline
            init(payload: UnsafeMutableRawPointer, table: _Table) {
                unsafe (self.payload = payload)
                self.table = table
            }

            deinit {
                unsafe table.destroy(payload)
            }
        }

        /// Table of type-specialized operations.
        ///
        /// The `destroy` function captures only type metadata (`T`'s layout),
        /// not user-provided runtime values. This is acceptable for Embedded
        /// compatibility as it's equivalent to generic specialization—no closure
        /// context with user data, only compiler-generated type information.
        ///
        // SAFETY: `_Table` stores a single immutable `@Sendable` closure
        // SAFETY: specialised at construction time for `T: ~Copyable`. The
        // SAFETY: closure captures only type metadata (T's layout), not
        // SAFETY: runtime values; the `Sendable` conformance is structural.
        // SAFETY: Encapsulation invariant per [MEM-SAFE-021] — internal table
        // SAFETY: type used only as `_Storage`'s table field.
        @usableFromInline
        struct _Table: Sendable {
            /// Destroys and deallocates the payload.
            /// Specialized for `T` at construction time.
            @usableFromInline
            let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

            @usableFromInline
            init<T: ~Copyable>(_: T.Type) {
                unsafe (self.destroy = { raw in
                    unsafe raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    unsafe raw.deallocate()
                })
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
        func _project<T: ~Copyable>(_: T.Type) -> UnsafePointer<T> {
            unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
        }

        // MARK: - Borrow Access

        /// Borrow access to the stored value via `_read`.
        ///
        /// Yields a borrow of the payload scoped to the accessor call.
        /// Supports `~Copyable` payloads — no copy is made.
        ///
        ///     V._render(value[as: V.self], context: &ctx)
        ///
        /// - Precondition: `T` must match the type used at construction.
        @inlinable
        public subscript<T: ~Copyable>(as type: T.Type) -> T {
            _read {
                precondition(
                    self.type == ObjectIdentifier(T.self),
                    "Machine.Value type mismatch: expected \(T.self), got type with id \(self.type)"
                )
                yield unsafe _project(type).pointee
            }
        }

        // MARK: - ~Escapable Ref

        /// A `~Escapable` reference to a stored value.
        ///
        /// Carries a lifetime dependency back to the `Value`, ensuring the
        /// reference cannot outlive its storage. Access the payload via
        /// the `value` property (`_read` accessor).
        @safe
        public struct Ref<T: ~Copyable>: ~Copyable, ~Escapable {
            @usableFromInline
            let _pointer: UnsafePointer<T>

            @usableFromInline
            init(_pointer: UnsafePointer<T>) {
                unsafe (self._pointer = _pointer)
            }

            /// Borrow access to the referenced value.
            public var value: T {
                _read { yield unsafe _pointer.pointee }
            }
        }

        /// Returns a `~Escapable` reference to the stored value.
        ///
        /// The returned `Ref` carries a lifetime dependency on `self`.
        /// No closure needed — use `ref.value` to borrow.
        ///
        /// Uses `_overrideLifetime` (the "returning model") to bridge
        /// from the raw pointer to the lifetime system.
        ///
        /// - Precondition: `T` must match the type used at construction.
        @_lifetime(borrow self)
        public func borrow<T: ~Copyable>(as type: T.Type) -> Ref<T> {
            precondition(
                self.type == ObjectIdentifier(T.self),
                "Machine.Value type mismatch: expected \(T.self), got type with id \(self.type)"
            )
            let ref = unsafe Ref(_pointer: _project(type))
            return unsafe _overrideLifetime(ref, borrowing: self)
        }
    }
}

// MARK: - Reference Mode Value Operations

extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(self[as: In.self]))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable, E: Swift.Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(self[as: In.self]))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out: Sendable>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(self[as: A.self], other[as: B.self]))
    }
}

// MARK: - Unchecked Mode Value Operations

extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(self[as: In.self]))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out, E: Swift.Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(self[as: In.self]))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(self[as: A.self], other[as: B.self]))
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
    public static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = unsafe _Storage(
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
    public static func make<T: ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = unsafe _Storage(
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

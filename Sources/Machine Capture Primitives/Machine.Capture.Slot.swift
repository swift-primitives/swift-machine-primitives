extension Machine.Capture {
    /// Table-based erased storage for a captured value.
    ///
    /// `Slot` stores a type-erased value using raw pointer storage and a
    /// type-specialized destroy function. No existentials (`AnyObject`, `Any`)
    /// or dynamic casts (`as?`, `as!`) are used.
    ///
    // WHY: Category D — structural Sendable workaround (SP-5).
    // WHY: Struct wraps _Storage (immutable after construction) + ObjectIdentifier.
    // WHY: @unchecked forced because inner _Storage is itself @unchecked.
    // WHEN TO REMOVE: When inner _Storage gains structural Sendable.
    // TRACKING: unsafe-audit-findings.md Category D SP-5.
    public struct Slot: @unchecked Sendable {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let storage: _Storage

        #if DEBUG
            @usableFromInline
            let typeName: String
        #endif

        /// Reference-counted storage for the erased payload.
        ///
        // WHY: Category D — structural Sendable workaround (SP-5) per [MEM-SAFE-024].
        // WHY: Immutable pointer + @Sendable destroy function. UnsafeMutableRawPointer
        // WHY: blocks structural inference. No synchronization.
        // WHY: Encapsulation invariant per [MEM-SAFE-021] — `_Storage` is `@usableFromInline`
        // WHY: but its raw-pointer storage is internal-only; consumers see only the
        // WHY: type-safe `Slot` surface.
        // WHEN TO REMOVE: When compiler gains structural Sendable through raw pointers.
        // TRACKING: unsafe-audit-findings.md Category D SP-5.
        @usableFromInline
        final class _Storage: @unchecked Sendable {
            @usableFromInline
            let payload: UnsafeMutableRawPointer

            @usableFromInline
            let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

            @usableFromInline
            init(
                payload: UnsafeMutableRawPointer,
                destroy: @escaping @Sendable (UnsafeMutableRawPointer) -> Void
            ) {
                unsafe (self.payload = payload)
                unsafe (self.destroy = destroy)
            }

            deinit {
                unsafe destroy(payload)
            }
        }

        /// Creates a slot storing the given value.
        @usableFromInline
        init<T>(_ value: T) {
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
            unsafe pointer.initialize(to: value)

            self.type = ObjectIdentifier(T.self)
            self.storage = unsafe _Storage(
                payload: UnsafeMutableRawPointer(pointer),
                destroy: { raw in
                    unsafe raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    unsafe raw.deallocate()
                }
            )
            #if DEBUG
                self.typeName = String(reflecting: T.self)
            #endif
        }

        /// Single choke-point for payload projection.
        ///
        /// All `assumingMemoryBound` calls for reading go through here.
        @usableFromInline
        func _project<T>(_: T.Type) -> UnsafePointer<T> {
            unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
        }

        /// Reads the stored value, checking the type matches.
        public func read<T>(_: T.Type) -> T {
            #if DEBUG
                precondition(
                    type == ObjectIdentifier(T.self),
                    "Capture type mismatch: expected \(T.self), stored \(typeName)"
                )
            #else
                precondition(type == ObjectIdentifier(T.self))
            #endif
            return unsafe _project(T.self).pointee
        }
    }
}

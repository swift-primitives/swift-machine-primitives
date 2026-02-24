extension Machine.Capture {
    /// Table-based erased storage for a captured value.
    ///
    /// `Slot` stores a type-erased value using raw pointer storage and a
    /// type-specialized destroy function. No existentials (`AnyObject`, `Any`)
    /// or dynamic casts (`as?`, `as!`) are used.
    ///
    /// ## Sendable
    ///
    /// `Slot` is `@unchecked Sendable` because:
    /// - `_Storage` is `@unchecked Sendable` (immutable after construction)
    /// - `type` is `ObjectIdentifier` which is Sendable
    /// - In Reference mode, only `T: Sendable` values can be stored (enforced at `Store.insert`)
    ///
    /// This conformance is only exercised when `Frozen<Mode.Reference>` derives
    /// Sendable, which requires all stored values to have been Sendable at insertion.
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
        /// `@unchecked Sendable` because:
        /// - `payload` pointer is immutable after construction
        /// - `destroy` is a `@Sendable` function (captures only type metadata)
        /// - The pointee is never mutated after construction
        /// - `deinit` is called exactly once when refcount hits zero
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
                self.payload = payload
                self.destroy = destroy
            }

            deinit {
                destroy(payload)
            }
        }

        /// Creates a slot storing the given value.
        @usableFromInline
        init<T>(_ value: T) {
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
            pointer.initialize(to: value)

            self.type = ObjectIdentifier(T.self)
            self.storage = _Storage(
                payload: UnsafeMutableRawPointer(pointer),
                destroy: { raw in
                    raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    raw.deallocate()
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
            UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
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
            return _project(T.self).pointee
        }
    }
}

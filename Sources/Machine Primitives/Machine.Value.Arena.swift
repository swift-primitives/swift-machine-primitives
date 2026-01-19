extension Machine.Value {
    /// A simple array-based arena for storing values during machine execution.
    ///
    /// `Arena` provides efficient allocation and deallocation of `Machine.Value`
    /// instances using slot-based handles. Values can be read, released, or
    /// the entire arena can be reset for reuse.
    public struct Arena: ~Copyable {
        @usableFromInline
        var values: [Machine.Value?]

        @usableFromInline
        var nextSlot: UInt32

        /// Creates an arena with the specified initial capacity.
        @inlinable
        public init(capacity: Int = 64) {
            self.values = [Machine.Value?](repeating: nil, count: capacity)
            self.nextSlot = 0
        }

        /// Allocates a value in the arena and returns a handle to it.
        @inlinable
        public mutating func allocate(_ value: consuming Machine.Value) -> Handle {
            let slot = nextSlot
            if Int(slot) >= values.count {
                values.append(contentsOf: repeatElement(nil, count: values.count))
            }
            values[Int(slot)] = value
            nextSlot += 1
            return Handle(slot: slot)
        }

        /// Reads the value at the given handle without removing it.
        @inlinable
        public func read(_ handle: Handle) -> Machine.Value {
            guard let value = values[Int(handle.slot)] else {
                fatalError("Arena.read: slot \(handle.slot) is empty")
            }
            return value
        }

        /// Releases and returns the value at the given handle.
        @inlinable
        public mutating func release(_ handle: Handle) -> Machine.Value {
            guard let value = values[Int(handle.slot)] else {
                fatalError("Arena.release: slot \(handle.slot) is empty")
            }
            values[Int(handle.slot)] = nil
            return value
        }

        /// Resets the arena for reuse, clearing all stored values.
        @inlinable
        public mutating func reset() {
            for i in 0..<Int(nextSlot) {
                values[i] = nil
            }
            nextSlot = 0
        }
    }
}

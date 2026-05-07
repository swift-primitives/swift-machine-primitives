// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-machine open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-machine project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Machine.Value {
    /// A simple array-based arena for storing values during machine execution.
    ///
    /// `Arena` provides efficient allocation and deallocation of `Machine.Value`
    /// instances using slot-based handles. Values can be read, released, or
    /// the entire arena can be reset for reuse.
    ///
    /// ## ABA Prevention
    ///
    /// The arena tracks a generation counter that increments on every `reset()`.
    /// Handles include the generation at allocation time. Operations validate
    /// that the handle's generation matches the current arena generation,
    /// preventing use of stale handles after reset.
    public struct Arena: ~Copyable {
        @usableFromInline
        var values: [Machine.Value<Mode>?]

        @usableFromInline
        var nextSlot: UInt32

        /// Current arena generation (incremented on reset).
        @usableFromInline
        var generation: UInt32

        /// Creates an arena with the specified initial capacity.
        @inlinable
        public init(capacity: Int = 64) {
            self.values = [Machine.Value<Mode>?](repeating: nil, count: capacity)
            self.nextSlot = 0
            self.generation = 0
        }

        /// Allocates a value in the arena and returns a handle to it.
        ///
        /// The returned handle includes the current arena generation for
        /// ABA prevention.
        @inlinable
        public mutating func allocate(_ value: consuming Machine.Value<Mode>) -> Handle {
            let slot = nextSlot
            if Int(slot) >= values.count {
                values.append(contentsOf: repeatElement(nil, count: values.count))
            }
            values[Int(slot)] = value
            nextSlot += 1
            return Machine.Value._makeHandle(slot: slot, generation: generation)
        }

        /// Validates that a handle belongs to the current arena generation.
        @inlinable
        func validateHandle(_ handle: Handle, operation: StaticString) {
            guard handle.generation == generation else {
                fatalError("Arena.\(operation): stale handle (generation \(handle.generation), current \(generation))")
            }
        }

        /// Reads the value at the given handle without removing it.
        ///
        /// - Parameter handle: A valid handle from this arena.
        /// - Returns: The value at the handle.
        /// - Precondition: The handle must be valid (correct generation, non-empty slot).
        @inlinable
        public func read(_ handle: Handle) -> Machine.Value<Mode> {
            validateHandle(handle, operation: "read")
            let slot = Machine.Value<Mode>._slot(handle)
            guard let value = values[Int(slot)] else {
                fatalError("Arena.read: slot \(slot) is empty")
            }
            return value
        }

        /// Releases and returns the value at the given handle.
        ///
        /// - Parameter handle: A valid handle from this arena.
        /// - Returns: The value that was at the handle.
        /// - Precondition: The handle must be valid (correct generation, non-empty slot).
        @inlinable
        public mutating func release(_ handle: Handle) -> Machine.Value<Mode> {
            validateHandle(handle, operation: "release")
            let slot = Machine.Value<Mode>._slot(handle)
            guard let value = values[Int(slot)] else {
                fatalError("Arena.release: slot \(slot) is empty")
            }
            values[Int(slot)] = nil
            return value
        }

        /// Resets the arena for reuse, clearing all stored values.
        ///
        /// All previously-issued handles become invalid after this call.
        /// The arena generation is incremented to detect stale handle usage.
        @inlinable
        public mutating func reset() {
            for i in 0..<Int(nextSlot) {
                values[i] = nil
            }
            nextSlot = 0
            generation &+= 1  // Increment with wrapping
        }
    }
}

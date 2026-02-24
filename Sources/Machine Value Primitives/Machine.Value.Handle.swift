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

public import Handle_Primitives

extension Machine.Value {
    /// Phantom type tag for machine value arena handles.
    ///
    /// This type exists solely to distinguish `Machine.Value.Handle` handles
    /// from other handle types at compile time.
    public enum _MachineValueArenaTag {}

    /// A handle to a value stored in an arena.
    ///
    /// `Handle` is a lightweight reference to a slot in a `Machine.Value.Arena`,
    /// enabling efficient value management during machine execution without
    /// copying values between stack frames.
    ///
    /// ## ABA Prevention
    ///
    /// Handles include a generation counter that is validated against the arena.
    /// When an arena is reset, its generation increments, invalidating all
    /// previously-issued handles. Attempts to use a stale handle will be detected.
    ///
    /// ## Implementation Note
    ///
    /// `Handle` is implemented as `Handle_Primitives.Handle<_MachineValueArenaTag>`
    /// to unify handle types across the Swift Institute primitives.
    public typealias Handle = Handle_Primitives.Handle<_MachineValueArenaTag>
}

// MARK: - Construction Helpers

extension Machine.Value {
    /// Creates a handle from a slot index and generation.
    ///
    /// - Parameters:
    ///   - slot: The slot index.
    ///   - generation: The arena generation at allocation time.
    /// - Returns: A handle suitable for external use.
    @usableFromInline
    static func _makeHandle(slot: UInt32, generation: UInt32) -> Handle {
        Handle(index: Int(slot), generation: generation)
    }

    /// Extracts the slot index from a handle.
    ///
    /// - Parameter handle: The value handle.
    /// - Returns: The slot index.
    @usableFromInline
    static func _slot(_ handle: Handle) -> UInt32 {
        UInt32(handle.index)
    }
}

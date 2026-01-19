extension Machine.Value {
    /// A handle to a value stored in an arena.
    ///
    /// `Handle` is a lightweight reference to a slot in a `Machine.Value.Arena`,
    /// enabling efficient value management during machine execution without
    /// copying values between stack frames.
    public struct Handle: Equatable, Hashable, Sendable {
        @usableFromInline
        let slot: UInt32

        @usableFromInline
        init(slot: UInt32) {
            self.slot = slot
        }
    }
}

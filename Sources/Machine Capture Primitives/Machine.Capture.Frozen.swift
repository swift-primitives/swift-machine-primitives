extension Machine.Capture {
    /// Immutable snapshot of captured values for program execution.
    ///
    /// `Frozen<Mode>` is produced by `Store<Mode>.freeze()` and used
    /// by the machine interpreter to access captured values at runtime.
    ///
    /// ## Sendable
    ///
    /// `Frozen<Mode>` is Sendable when `Mode: Sendable`. For `Mode.Reference`,
    /// this is sound because:
    /// - All values were inserted via `Store.insert<T: Sendable>`
    /// - `Slot` is `@unchecked Sendable` with construction-enforced invariants
    /// - The slots array is immutable (`let`)
    public struct Frozen<Mode> {
        public let slots: [Slot]

        @usableFromInline
        init(__slots: [Slot]) {
            self.slots = __slots
        }
    }
}

// MARK: - Sendable

extension Machine.Capture.Frozen: Sendable where Mode: Sendable {}

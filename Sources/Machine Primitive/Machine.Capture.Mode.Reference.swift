extension Machine.Capture.Mode {
    /// The Sendable capture mode: payloads must be `Sendable` and captures may cross isolation domains.
    public struct Reference: Sendable {
        @usableFromInline
        init() {}
    }
}

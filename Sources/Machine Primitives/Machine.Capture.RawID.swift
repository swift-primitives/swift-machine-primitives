extension Machine.Capture {
    public struct RawID: Hashable, Sendable {
        @usableFromInline let rawValue: Int

        @usableFromInline
        init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

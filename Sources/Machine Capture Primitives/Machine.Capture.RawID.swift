extension Machine.Capture {
    public struct RawID: Hashable, Sendable {
        public let rawValue: Int

        @usableFromInline
        init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

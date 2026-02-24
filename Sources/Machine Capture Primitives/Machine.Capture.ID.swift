extension Machine.Capture {
    public struct ID<Value>: Hashable, Sendable {
        public let raw: RawID

        @usableFromInline
        init(_ raw: RawID) {
            self.raw = raw
        }

        @inlinable
        public var rawValue: Int { raw.rawValue }
    }
}

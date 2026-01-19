extension Machine.Value {
    /// Internal storage class for type-erased values.
    ///
    /// This simple heap-allocated box stores any value type, enabling
    /// `Machine.Value` to hold values of any type without existentials.
    /// ARC handles memory management automatically.
    @usableFromInline
    final class Box<T> {
        @usableFromInline
        let value: T

        @usableFromInline
        init(_ value: T) {
            self.value = value
        }
    }
}

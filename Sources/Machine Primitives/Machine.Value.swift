extension Machine {
    /// A type-erased value container for the machine's runtime.
    ///
    /// `Value` stores any type-erased value during machine execution, preserving
    /// the original type information via `ObjectIdentifier` for safe extraction.
    /// This avoids protocol existentials and enables efficient value passing
    /// between machine nodes.
    @safe
    public struct Value {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let box: AnyObject

        @usableFromInline
        init(type: ObjectIdentifier, box: AnyObject) {
            self.type = type
            self.box = box
        }

        /// Creates a type-erased value from a concrete value.
        @inlinable
        public static func make<T>(_ value: T) -> Value {
            let box = Box(value)
            return Value(
                type: ObjectIdentifier(T.self),
                box: box
            )
        }

        /// Attempts to extract the value as the specified type.
        ///
        /// Returns `nil` if the type does not match.
        @inlinable
        public func take<T>(_ expectedType: T.Type) -> T? {
            guard type == ObjectIdentifier(T.self) else {
                return nil
            }
            guard let typedBox = box as? Box<T> else {
                return nil
            }
            return typedBox.value
        }

        /// Extracts the value as the specified type without type checking.
        ///
        /// - Precondition: The value must have been created with the same type.
        @inlinable
        public func unsafeTake<T>(_ expectedType: T.Type) -> T {
            precondition(
                type == ObjectIdentifier(T.self),
                "Machine.Value type mismatch: expected \(T.self), got type with id \(type)"
            )
            guard let typedBox = box as? Box<T> else {
                fatalError("Machine.Value box downcast failed: expected Box<\(T.self)>")
            }
            return typedBox.value
        }
    }
}

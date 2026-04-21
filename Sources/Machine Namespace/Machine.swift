/// A namespace for defunctionalized machine-based parsing infrastructure.
///
/// `Machine` provides the core building blocks for representing parsers as data
/// (programs) rather than closures, enabling zero-copy parsing with Swift 6's
/// `~Escapable` types where the lifetime checker rejects closures at abstraction
/// boundaries.
///
/// The Machine infrastructure is generic over:
/// - `Leaf`: The primitive operations (cursor-specific)
/// - `Failure`: The error type for fallible operations
///
/// Cursor-specific packages (Parsing, Binary) provide their own leaf types
/// and inlined interpreters while sharing this common infrastructure.
public enum Machine {}

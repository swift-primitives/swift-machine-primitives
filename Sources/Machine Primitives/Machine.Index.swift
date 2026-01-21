//// ===----------------------------------------------------------------------===//
////
//// This source file is part of the swift-primitives open source project
////
//// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
//// Licensed under Apache License v2.0
////
//// See LICENSE for license information
////
//// ===----------------------------------------------------------------------===//
//
//public import Index_Primitives
//
//extension Machine {
//    /// Type-safe index for capture group positions.
//    ///
//    /// Uses `Index<Capture>` to provide compile-time safety preventing
//    /// confusion between capture indices and other index types.
//    ///
//    /// ## Example
//    ///
//    /// ```swift
//    /// let captureIdx: Machine.CaptureIndex = 0
//    /// // Access capture group 0 (typically the full match)
//    /// ```
//    public typealias CaptureIndex = Index_Primitives.Index<Capture>
//
//    /// Phantom type for capture group indexing.
//    public enum Capture {}
//}

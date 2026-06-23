// DEPRECATED — transitional shim (L1 core-dissolution sweep 2026-06-23). Re-exports the dissolved Core surface; removed in the cleanup wave.
//
// The `Machine.Capture*` declarations that previously lived here now live in
// the zero-dependency `Machine Primitive` root. This target survives only as an
// exports-only shim so consumers of the `Machine Primitives Core` product keep
// compiling until the cleanup wave repoints them to the umbrella / root.
@_exported public import Machine_Primitive
@_exported public import Graph_Primitives

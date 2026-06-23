# Machine Primitives Scope

`swift-machine-primitives` provides the **defunctionalized machine substrate** —
the infrastructure for representing parsers as data (programs over a node graph)
rather than closures, so Swift 6's lifetime checker can reject escaping closures
at abstraction boundaries while preserving zero-copy parsing. It owns the
`Machine` namespace and the capture / value / carrier / composition vocabulary
that cursor-specific packages (Parsing, Binary) build their leaf interpreters on.

## Per-[MOD-031] shape

The package follows `[MOD-017]` (singular `Machine Primitive` root) +
`[MOD-031]` (per-sub-namespace decomposition). `Machine Primitive` is the
zero-external-dependency namespace target; it owns `public enum Machine` and the
stdlib-only `Machine.Capture` / `Machine.Capture.Mode` foundational vocabulary.
Each external-dependency-bearing concern is its own sub-namespace target.

The legacy `[MOD-001]` `Machine Primitives Core` target is **deprecated**. During
the L1 core-dissolution sweep (2026-06-23) its four `Machine.Capture*`
declarations — all stdlib-only — folded into the `Machine Primitive` root.
Empirical validation found **no Core declaration used a `Graph_Primitives`
symbol**: Core's `Graph_Primitives` re-export was a pure funnel, not a
declaration dependency, so no `Machine Graph Primitives` sub-namespace was
created. The real Graph consumers (`Machine Node Primitives`,
`Machine Program Primitives`) now declare `Graph Primitives` directly per
`[MOD-038]`. `Machine Primitives Core` survives only as a time-boxed
exports-only shim re-exporting the dissolved surface (root + funneled
`Graph_Primitives`); it is removed in the cleanup wave once consumers repoint to
the umbrella.

## Owner targets

- **Machine Primitive** — the `public enum Machine {}` namespace target plus the
  zero-dependency `Machine.Capture`, `Machine.Capture.Mode`,
  `Mode.Reference`, and `Mode.Unchecked` foundational declarations. Zero external
  deps per `[MOD-017]`.
- **Machine Value Primitives** — `Machine.Value` type-erased runtime value
  container (`~Copyable` payload support, `~Escapable` `Ref` borrow access).
- **Machine Capture Primitives** — `Machine.Capture.Frozen` / `ID` / `RawID` /
  `Slot` / `Store` capture storage discipline.
- **Machine Transform / Combine / Next / Finalize Primitives** — the carrier
  combinator vocabulary (erased + typed-throws transforms, binary combines,
  flat-map continuations, array/fold finalizers).
- **Machine Frame Primitives** — `Machine.Frame` composition over the carriers.
- **Machine Node Primitives** — `Machine.Node` program-graph node; declares
  `Graph Primitives` for `Graph.Node` IDs + `Graph.Adjacency.Extract`.
- **Machine Program Primitives** — `Machine.Program` + `Builder` over
  `Graph.Sequential` storage; declares `Graph Primitives` directly.
- **Machine Convenience Primitives** — builder/program ergonomics over the
  carriers.
- **Machine Primitives** — umbrella; re-exports the root + every sub-namespace
  (and funnels `Graph_Primitives`) so consumers write `import Machine_Primitives`.
- **Machine Primitives Core** — DEPRECATED time-boxed shim (see above).
- **Machine Primitives Test Support** — published test-fixtures product.

## Out of scope

- Cursor-specific leaf operations and inlined interpreters (Parsing, Binary)
  live in their own packages; they USE this substrate's `Machine` namespace and
  provide their own `Leaf` types.
- Graph algorithms and the directed-graph data-structure substrate live in
  `swift-graph-primitives`; this package only USES `Graph.Node` /
  `Graph.Adjacency` / `Graph.Sequential`.

## Evaluation rule

Sub-target additions are evaluated against this scope.

- A proposed addition that is **stdlib-only `Machine` namespace vocabulary**
  (a capture mode, a namespace enum) lands in the `Machine Primitive` root.
- A proposed addition whose declarations **use an external module** lands in the
  owning sub-namespace target (existing or new), which declares that dependency
  directly per `[MOD-038]` — never via a funnel re-export.
- A proposed addition that is a **cursor-specific leaf / interpreter** extracts
  to a sibling package, not into this one.

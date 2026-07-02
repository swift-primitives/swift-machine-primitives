# swift-machine-primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Defunctionalized parsing substrate that represents parsers as a graph of data nodes with transforms held in a capture store rather than as closures, letting Swift 6's lifetime checker accept zero-copy parsing across abstraction boundaries.

---

## Quick Start

Build a parser program as data. Carriers — transforms, combines, continuations, finalizers — are defunctionalized into handles stored in a capture store, so the node graph itself holds no closures. That separation is what lets `~Escapable` cursors cross abstraction boundaries the compiler rejects for escaping closures.

```swift
import Machine_Primitives

// `Leaf` (cursor primitives) and `Failure` come from a cursor-specific parsing
// package; empty stubs keep this example self-contained.
enum Leaf {}
enum Failure: Error {}

typealias Mode = Machine.Capture.Mode.Reference

var builder = Machine.Builder<Leaf, Failure, Mode>()

// Defunctionalize a closure: it is stored once in the capture store and
// referenced by a handle, so the nodes that use it stay plain, Sendable data.
let add = builder.combine { (a: Int, b: Int) in a + b }

// Assemble a graph of data-only nodes — two pure values combined in sequence.
let lhs = builder.allocate(.pure(.make(20)))
let rhs = builder.allocate(.pure(.make(22)))
let root = builder.allocate(.sequence(a: lhs, b: rhs, combine: add))

let program = builder.build()
print(program[root].adjacent)   // [lhs, rhs] — the program is inspectable data, not opaque closures

// Values are type-erased without existentials (`Any` / `as?`) and recovered at
// their exact original type; the carrier runs through the frozen capture store.
let sum = program.combine(add, .make(20), .make(22))
print(sum[as: Int.self])        // 42
```

`Machine.Value` carries payloads through table-based storage, so erasure needs no `Any` or `as?` cast. `Mode.Reference` constrains payloads to `Sendable`; `Mode.Unchecked` drops that requirement.

---

## Key Features

- **Parsers as data** — a `Machine.Program` is a graph of `Machine.Node` values; the parser tree carries data, never embedded closures.
- **Defunctionalized carriers** — `Transform.Erased`, `Transform.Throwing`, `Combine.Erased`, `Next.Erased`, and `Finalize.Array` are each stored once in a capture store and referenced by handle.
- **Existential-free type erasure** — `Machine.Value` moves any payload through table-based storage with no `Any` / `as?` casts and recovers it at its exact original type.
- **Move-only payloads** — `Value` supports `~Copyable` payloads and exposes a lifetime-dependent `~Escapable` `Ref` for borrow access.
- **Two capture modes** — `Mode.Reference` constrains payloads to `Sendable`; `Mode.Unchecked` lifts that constraint for single-domain use.
- **Builder to immutable program** — `Machine.Builder` accumulates nodes and captures, then `build()` freezes them into a `Sendable` `Program` over `Graph.Sequential` storage.
- **Foundation-free** — no `import Foundation` anywhere in the sources.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-machine-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Machine Primitives", package: "swift-machine-primitives")
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26.

---

## Architecture

The `Machine` namespace and its vocabulary are split across one root target and per-concern sub-namespace targets; `Machine Primitives` is the umbrella that re-exports all of them. Import `Machine_Primitives` for the whole substrate, or a single sub-namespace target when you need a narrower surface.

| Product | Purpose |
|---------|---------|
| `Machine Primitive` | The `Machine` namespace plus the dependency-free `Machine.Capture`, `Machine.Capture.Mode`, and the `Mode.Reference` / `Mode.Unchecked` capture modes. |
| `Machine Value Primitives` | `Machine.Value` — a type-erased runtime container with `~Copyable` payload support and a lifetime-dependent `Ref` borrow. |
| `Machine Capture Primitives` | The capture store: `Capture.Store`, `Capture.Frozen`, `Capture.ID`, `Capture.RawID`, `Capture.Slot`. |
| `Machine Transform Primitives` | Unary carriers: `Transform.Erased` and the typed-throws `Transform.Throwing`. |
| `Machine Combine Primitives` | Binary carriers: `Combine.Erased`. |
| `Machine Next Primitives` | Flat-map continuation carriers: `Next.Erased`. |
| `Machine Finalize Primitives` | Collection carriers: `Finalize.Array` backing the `many` and `fold` nodes. |
| `Machine Frame Primitives` | `Machine.Frame` composition over the carriers. |
| `Machine Node Primitives` | `Machine.Node` — the program-graph node enum (`leaf`, `pure`, `map`, `sequence`, `oneOf`, `many`, `fold`, `optional`, `ref`, `hole`). |
| `Machine Program Primitives` | `Machine.Program` and its mutable `Builder` over `Graph.Sequential` storage. |
| `Machine Convenience Primitives` | Builder/program ergonomics: carrier factory methods and `apply` helpers. |
| `Machine Primitives` | Umbrella re-exporting every target above; the product consumers import. |
| `Machine Primitives Test Support` | Test fixtures re-exported for downstream test targets. |

The single external dependency is [swift-graph-primitives](https://github.com/swift-primitives/swift-graph-primitives), used for the `Graph.Node` IDs and `Graph.Sequential` storage that back the program graph. Cursor-specific leaf operations and their interpreters live in their own packages (Parsing, Binary), which provide their own `Leaf` types over this substrate.

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public release.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).

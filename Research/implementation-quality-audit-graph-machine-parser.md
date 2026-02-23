# Implementation Quality Audit: Graph, Machine, and Parser-Machine Primitives

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 2
scope: graph-primitives, machine-primitives, parser-machine-primitives
workflow: discovery
---
-->

## Context

Three packages form a dependency chain for defunctionalized parser infrastructure:

```
graph-primitives          (48 files, 1 module)
       ↑
machine-primitives        (38 files, 2 modules: Core + Conveniences)
       ↑
parser-machine-primitives (22 files, 1 module)
```

The `Machine.Program → Graph.Sequential` migration is complete. Before building optimization passes on this foundation, we need to audit: (1) whether the module organization follows ecosystem conventions (Core/public split per array-primitives pattern), and (2) whether implementation quality meets [IMPL-*] requirements.

## Question

Two questions:

1. **Module organization**: Should these packages adopt the Core/public module split used by array-primitives, buffer-primitives, and other mature packages?
2. **Implementation quality**: Do these packages meet [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-002], [PATTERN-017], and other implementation skill requirements?

---

## Analysis

### Part 1: Module Organization

#### The Core/Public Split Pattern (Reference: array-primitives)

Array-primitives uses this architecture:

```
Array Primitives Core          (base types, ~Copyable subscripts, error types)
Array Dynamic Primitives       (Swift.Sequence/Collection where Element: Copyable)
Array Fixed Primitives         (Swift.Collection where Element: Copyable)
Array Static Primitives        (copy subscript where Element: Copyable)
Array Small Primitives         (iterator where Element: Copyable)
Array Bounded Primitives       (modular arithmetic, hash)
Array Primitives               (re-exports all of the above)
```

**Why it exists**: Core defines `Array<Element: ~Copyable>` with fundamental methods. Variant modules add `where Element: Copyable` extensions (Swift.Sequence/Collection conformances, copy subscripts). Without this split, adding `Copyable`-specific extensions to a `~Copyable`-generic type causes constraint poisoning — the compiler infers `Element: Copyable` at the extension level, rejecting `~Copyable` elements.

**The split is driven by a specific compiler limitation**, not general organizational preference.

#### Graph-Primitives: No Split Needed

`Graph.Sequential<Tag, Payload>` requires `Payload: Sendable` but not `Payload: Copyable`. There are no Copyable-specific extensions (no Swift.Collection conformance, no copy subscripts). No constraint poisoning risk.

| Component | Would go in Core | Would go in public |
|-----------|------------------|--------------------|
| Graph.Sequential, Builder | ✓ | |
| Adjacency.Extract, List, Remap | ✓ | |
| Traversal iterators (DFS, BFS, topological) | | ✓ |
| Analysis algorithms (reachable, dead, SCC, cycles, transitive closure) | | ✓ |
| Path finding (exists, shortest, weighted) | | ✓ |
| Transforms (payloads, subgraph) | | ✓ |
| Reverse (reversed, backward reachable) | | ✓ |

A split here would separate "data structure" from "algorithms." But algorithms are the entire value proposition — `Graph.Sequential` without them is a typed `Array.Indexed`. The algorithms don't introduce constraint poisoning. They don't need separate compilation boundaries.

**Recommendation: Keep single module.** The 48 files are manageable. Splitting would add package management overhead without solving a real problem. If the package grows significantly (e.g., adding sparse graph types, mutable graph types), reconsider.

#### Machine-Primitives: Current Split Is Adequate

Machine-primitives already has a two-module split:

```
Machine Primitives              (Node, Program, Builder, Value, Capture, Frame, type-erased carriers)
Machine Primitives Conveniences (Builder+Carriers factory methods, Program+Apply convenience)
```

A Core/public split would look like:

| Component | Core | Public |
|-----------|------|--------|
| Machine.Node (enum cases) | ✓ | |
| Machine.Program, Builder | ✓ | |
| Machine.Value, Arena, Handle | ✓ | |
| Machine.Capture (Store, Frozen, Slot, ID, RawID) | ✓ | |
| Machine.Frame, Frame.Sequence | ✓ | |
| Transform.Erased (struct + _apply) | ✓ | |
| Transform.Erased Reference/Unchecked inits | | ✓ |
| Combine.Erased, Next.Erased, Finalize.Array (same pattern) | same split | |
| Conveniences (Builder+Carriers, Program+Apply) | | ✓ |

The type-erased carriers (Transform.Erased, Combine.Erased, Next.Erased, Finalize.Array) have their struct declarations in Core but mode-specific initializers (`where Mode == Mode.Reference` / `where Mode == Mode.Unchecked`) in separate extensions. These extensions don't cause constraint poisoning because `Mode` is not `~Copyable`-constrained.

**Recommendation: Current split is adequate.** The Core/Conveniences boundary already separates data types from factory methods. A more granular split (Core + carriers + conveniences) would add a module boundary inside the type-erased carrier pattern without clear benefit. The mode-specific extensions work fine as same-module extensions.

#### Parser-Machine-Primitives: No Split Needed

Single domain, tightly integrated. The run loop (`Parser.Machine.Run`) needs direct access to all types (Frame, Value, Arena, Program). The memoization subsystem is a natural subdirectory, not a separate module.

**Recommendation: Keep single module.** The 22 files are focused and coherent. No constraint poisoning risk. No Copyable-specific extensions.

---

### Part 2: Implementation Quality

#### Graph-Primitives

**Overall: 9/10 — Excellent.**

**Strengths worth preserving:**

1. **retag() pattern** throughout. Node ID conversions use `.retag(Bit.self)`, `.retag(Payload.self)`, `.retag(Tag.self)` — zero rawValue at call sites. Example from `Graph.Sequential.Builder`:
   ```swift
   public var count: Graph.Node<Tag>.Count { storage.count.retag(Tag.self) }
   public subscript(node: Graph.Node<Tag>) -> Payload {
       get { storage[node.retag(Payload.self)] }
   }
   ```

2. **~Copyable iterators**. `Traversal.First.Depth` and `Traversal.First.Breadth` are `~Copyable, Sequence.Iterator.Protocol`. Enforces linear consumption — you cannot accidentally fork a traversal.

3. **Closure-based witness pattern**. `Adjacency.Extract` and `Remappable.Remap` use stored closures instead of protocol conformance. Enables graph algorithms on any payload type without retroactive conformance.

4. **Consistent accessor pattern**. `graph.traverse.first.depth(from:)`, `graph.analyze.reachable(from:)`, `graph.path.shortest(from:to:)`, `graph.transform.subgraph(inducedBy:)`, `graph.reverse.reversed()`. Uniform namespace + method discovery.

5. **@inlinable/@usableFromInline** consistently applied. All public methods are `@inlinable`. Internal storage is `@usableFromInline`. Enables cross-module optimization.

**Issues found:**

| ID | File | Severity | Description |
|----|------|----------|-------------|
| G-1 | `Graph.Sequential.Transform.Subgraph.swift:41-46` | **Critical** | Generic `subgraph(inducedBy:using:)` creates sentinel nodes (`Ordinal(UInt(bitPattern: -1))`) for edges pointing outside the subgraph. The remapped payload contains invalid node references. Violates the documented invariant: "all adjacency references in returned payload are within `0..<newNodeCount`." The List-specific overload correctly filters edges before remapping. |
| G-2 | `Graph.Sequential.swift:53` | Minor | `nodes` property chains `Int(bitPattern: count)` → range → `.lazy.map { Node<Tag>(__unchecked: (), Ordinal(UInt($0))) }` — mechanism leak in a public property. Should have a dedicated factory or iterator. |
| G-3 | `Package.swift:29,31` | Minor | `swift-index-primitives` dependency listed twice. |
| G-4 | `Graph.Sequential.Analyze.SCC.swift:22` | Minor | `Array<Int>.Fixed.Indexed<Tag>` with -1 sentinels. Untyped Int array for Tarjan state. Acceptable for algorithm performance, but worth noting as a principled departure from typed arithmetic. |
| G-5 | `exports.swift` | Minor | No comment explaining why Stack, Queue, Heap, Bit_Vector, Sequence primitives are not re-exported (intentionally internal algorithm dependencies). |

**G-1 remediation**: The generic `subgraph` should either:
- (a) Accept a `Remap` that includes edge filtering (change `mapNodes` signature to return `Optional<Payload>`), or
- (b) Pre-filter edges using `Extract.adjacent()` before remapping, discarding edges pointing outside the subgraph, or
- (c) Document the contract: "The remap function must handle nodes not present in the subgraph."

Option (b) is cleanest — it matches what the List-specific overload already does, generalized.

#### Machine-Primitives

**Overall: 9/10 — Excellent.**

**Strengths worth preserving:**

1. **Type erasure without existentials**. `Machine.Value` and `Machine.Capture.Slot` use table-based storage: `ObjectIdentifier` for type tag, `UnsafeMutableRawPointer` for payload, `_Table` with type-specialized destroy. Single choke-point `_project()` for all unsafe bindings. No `AnyObject`, `Any`, or `as?` casts.

2. **Meticulous Sendable handling**. Five-layer Sendable strategy:
   - `_Storage: @unchecked Sendable` — justified (immutable after construction)
   - `_Table: Sendable` — contains only type metadata, no user closures
   - `Value<Mode>` conditionally Sendable via `Mode: Sendable`
   - `Mode.Reference` enforces `T: Sendable` at construction
   - `Mode.Unchecked` intentionally NOT Sendable
   Each layer documented with rationale.

3. **Mode stratification via extension specialization**. `where Mode == Mode.Reference` and `where Mode == Mode.Unchecked` provide two APIs from one type. Reference enforces Sendable; Unchecked does not. No protocol, no associated type, no type-level complexity.

4. **Consuming Builder**. `Machine.Builder: ~Copyable` with `consuming func build() -> Program`. Prevents accidental re-use of builder state. Hole patching via subscript `builder[id] = .ref(root)`.

5. **Type-erased carrier pattern**. `Transform.Erased`, `Combine.Erased`, `Next.Erased`, `Finalize.Array` — all follow identical structure: `capture: RawID` + `_operation: @Sendable (borrowing Frozen, ...) -> ...` + public `apply/combine/next/finalize` method.

**Issues found:**

| ID | File | Severity | Description |
|----|------|----------|-------------|
| M-1 | `Machine.Transform.Throwing.swift:35-36` | ~~Medium~~ Documented | Direct access to `captures.slots[raw.rawValue]` instead of `withRawThrowing`. Investigated: the Swift compiler crashes (signal 11) when `withRawThrowing`'s body closure annotates `throws(Failure)` in this nested typed-throws context. Direct access performs the identical operations (`slots[raw.rawValue]` + `slot.read(T.self)`). Documented as WORKAROUND per [PATTERN-016]. |
| M-2 | `Machine.Value.swift:145-149` | Minor | `make()` creates intermediate `let table = _Table(T.self)` before passing to `_Storage`. Could inline: `_Storage(payload: ..., table: _Table(T.self))`. Per [IMPL-EXPR-001], the intermediate adds no explanatory value. |
| M-3 | `Machine.Builder+Carriers.swift` | Minor | Only `Mode.Reference` convenience methods provided. No `Mode.Unchecked` equivalents. If Unchecked mode has consumers, they lack the same ergonomics. |

**M-1 resolution**: Direct slot access is a documented workaround (WORKAROUND comment added per [PATTERN-016]). The compiler crashes (signal 11) with nested typed throws closures when `withRawThrowing`'s body annotates `throws(Failure)`. The operations are functionally identical — `slots[raw.rawValue]` + `slot.read(T.self)` — just without the closure boundary. Revisit when Swift fixes nested typed throws in closure contexts.

#### Parser-Machine-Primitives

**Overall: 9.5/10 — Outstanding.**

**Strengths worth preserving:**

1. **Stack-safe execution**. Pre-allocated frame stack + depth counter. No call-stack growth. Proven at 5000-level recursive nesting in tests.

2. **Complete packrat memoization**. Cache at `(position, node)` pairs. Both successes and failures cached. Edit-based cache invalidation for incremental reparsing.

3. **Three-stage compilation pipeline**. Build (eagerly construct AST) → Lazy (`Compiled<P>`, compiles on first parse) → Eager (`Prepared<P>`, compiles immediately, `Sendable`). Users choose.

4. **rawValue strictly confined**. `current.rawValue` appears only in memoization key construction inside the run loop. Never exposed to builder or parser users.

5. **Witness-based compilation**. `Compile.Witness<P>` is a value, not a protocol. Each parser type provides a witness that knows how to compile itself. Avoids protocol-based compilation dispatch.

**Issues found:**

| ID | File | Severity | Description |
|----|------|----------|-------------|
| P-1 | `Parser.Machine.Run.swift` | Minor | Run function is ~300 lines. Mechanically correct but dense. Helper extraction for individual frame-processing cases would improve readability. However, inlining concerns may justify keeping it monolithic — extracting helpers could prevent the optimizer from specializing the hot path. |
| P-2 | `Parser.Machine.Run.Memoization.swift:199` | Minor | `current.rawValue` used for memo key. This is the only rawValue leak, confined to the run loop, justified by memoization needing a hashable key. Could use `.retag(MemoTag.self)` if a phantom tag existed, but this would be over-engineering. |

---

### Part 3: Cross-Package Consistency

| Convention | graph | machine | parser-machine |
|------------|-------|---------|----------------|
| `@inlinable` on public API | ✓ | ✓ | ✓ |
| `@usableFromInline` on internals | ✓ | ✓ | ✓ |
| Conditional `Sendable` | ✓ | ✓ | ✓ |
| `~Copyable` where appropriate | ✓ (iterators) | ✓ (Builder, Arena) | ✓ (Builder) |
| `.retag()` over `.rawValue` | ✓ | ✓ | ✓ (except memo key) |
| No Foundation | ✓ | ✓ | ✓ |
| One type per file | ✓ | ✓ | ✓ |
| Typed throws | N/A (no throws) | ✓ (`throws(Failure)`) | ✓ (`throws(Failure)`) |
| `@safe` annotation | N/A | ✓ (Node, Value, Frame, carriers) | N/A |
| Consuming builder | ✓ (`build()`) | ✓ (`build()`) | ✓ (via machine) |
| Documentation comments | ✓ | ✓ | ✓ |

**The packages are highly consistent.** Style, access control, and patterns are uniform across the chain. The main deviation is the module organization question, which is addressed in Part 1.

---

## Outcome

**Status**: RECOMMENDATION

### Module Organization

| Package | Current | Recommended | Rationale |
|---------|---------|-------------|-----------|
| graph-primitives | 1 module | **Keep 1 module** | No constraint poisoning. Algorithms are the value proposition. |
| machine-primitives | 2 modules (Core + Conveniences) | **Keep 2 modules** | Adequate separation. Further split adds complexity without need. |
| parser-machine-primitives | 1 module | **Keep 1 module** | Single domain, tightly integrated. |

The Core/public split pattern is driven by constraint poisoning in `~Copyable`-generic types that need `Copyable`-specific extensions. None of these three packages have that problem. The pattern should not be applied where the driver doesn't exist.

### Implementation Fixes (Prioritized)

| Priority | ID | Package | Fix |
|----------|-----|---------|-----|
| 1 | G-1 | graph | ~~Fix generic `subgraph` edge filtering~~ **FIXED** — pre-validates all edges target included nodes, returns `nil` if not self-contained |
| 2 | M-1 | machine | ~~Use `withRawThrowing`~~ **DOCUMENTED** — compiler crash (signal 11) with nested typed throws; added WORKAROUND comment per [PATTERN-016] |
| 3 | G-3 | graph | Remove duplicate swift-index-primitives dependency |
| 4 | M-2 | machine | Inline `_Table` construction in Value.make() |
| 5 | G-2 | graph | Improve `nodes` property — reduce mechanism in lazy map chain |
| 6 | G-5 | graph | Add comment to exports.swift explaining non-exported algorithm dependencies |

### Patterns to Preserve

1. **retag() over rawValue** — the single most impactful convention across all three packages
2. **Closure-based witnesses** (Extract, Remap, Compile.Witness) — avoids protocol machinery
3. **Table-based type erasure** — no existentials, single choke-point for unsafe
4. **Mode stratification via extension specialization** — Reference/Unchecked without protocol complexity
5. **Consuming builders** — linear ownership for construction
6. **Consistent accessor pattern** — `graph.traverse`, `graph.analyze`, `program.apply`

## References

- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Package.swift` — Core/public split reference implementation
- [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-002], [PATTERN-017] — Implementation skill requirements
- [API-IMPL-005] — One type per file
- [PRIM-FOUND-001] — No Foundation
- [PATTERN-022] — ~Copyable constraint poisoning
- `graph-discipline-boundary-analysis.md` — Prior boundary audit for graph-primitives
- `graph-operations-audit.md` — Prior operations audit for graph-primitives

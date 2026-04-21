# Audit: swift-machine-primitives

## Implementation — 2026-04-21

### Scope

- **Target**: swift-machine-primitives (test files under `Tests/`)
- **Skill**: implementation — [IMPL-061] Compiler fix before workaround accumulation; [IMPL-077] Verify the constraint by minimal experiment before implementing a workaround
- **Files**: 3 test files carrying a fileprivate `insert` overload workaround

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | MEDIUM | [IMPL-061] | `Tests/Machine Transform Primitives Tests/Machine.Transform Tests.swift:4-21`, `Tests/Machine Frame Primitives Tests/Machine.Frame Tests.swift:4-15`, `Tests/Machine Node Primitives Tests/Machine.Node Tests.swift:4-15` | Fileprivate `insert` overload on `Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference` with nested-generic `dispatchToBase<V: Sendable>` routes typed-throws `@Sendable` closure literals past a Swift 6.3.1 SILGen crash (signal 5 in `createInputFunctionArgument` / `LoweredParamGenerator::claimNext`) that fires when `{ ... } as @Sendable (In) throws(E) -> Out` is passed directly into `Store.insert<V: Sendable>(_:)`. 8 call sites migrated to trailing-closure form. No `unsafe`, no compound identifiers. | DEFERRED — Swift 6.3.1 SILGen bug; revisit on 6.4-dev nightly. Investigation pointer: `swift-institute/Experiments/silgen-sendable-typed-throws-closure-cast/` (commit `a4526ea` in `swift-institute/Experiments` main). Workaround commit: `dff4b80` on `swift-machine-primitives` main. Prior art (different compositional driver, same bug class): `swift-institute/Experiments/silgen-thunk-noncopyable-sending-capture/` and `swift-institute/Research/silgen-bug-prone-primitive-compositions.md`. When revisiting: re-run the experiment on the nightly; if the crash is FIXED, remove the three fileprivate extensions and restore each call site to `store.insert({ ... } as @Sendable ...)` inline form, per [EXP-006] FIXED verdict handling. |
| 2 | LOW | [IMPL-077] | `Sources/Machine Transform Primitives/Machine.Transform.Throwing.swift:35-38` | Pre-existing source-side SILGen workaround comment — direct `captures.slots[raw.rawValue]` instead of `withRawThrowing`, citing "compiler crashes (signal 11) with nested typed throws closures when withRawThrowing's body closure annotates throws(Failure)". Distinct composition from finding #1 (signal 11 vs signal 5; `withRawThrowing` body vs `Store.insert` caller) but same SILGen-fragility-around-typed-throws-closures class. Finding #1's experiment does NOT capture this variant. | DEFERRED — Swift SILGen bug; revisit when finding #1 is revisited. Consider filing a second minimal reproducer for the `withRawThrowing` / nested typed-throws case to complete the catalog in `Research/silgen-bug-prone-primitive-compositions.md`. |

### Summary

2 findings: 0 critical, 0 high, 1 medium, 1 low.

Both findings are DEFERRED SILGen workarounds parked per [AUDIT-017]. They represent two distinct expressions of the same Swift 6.3.1 SILGen-fragility-around-typed-throws-closures bug class, one on the test side (finding #1, landed this audit cycle) and one on the source side (finding #2, pre-existing). Revisit in lockstep: the 6.4-dev nightly sweep that removes the test-side workaround should also re-test the source-side pattern; if either is fixed, both sites should be audited and restored to canonical form.

---

## Legacy — Consolidated 2026-04-08

### From: implementation-quality-audit-graph-machine-parser.md (2026-02-23)

**Scope**: Cross-package implementation quality and module organization audit for graph-primitives (48 files), machine-primitives (38 files, 2 modules), and parser-machine-primitives (22 files).

**Auditor**: Claude | **Status**: RECOMMENDATION

**Overall scores**: graph 9/10, machine 9/10, parser-machine 9.5/10

**Module organization recommendations**:

| Package | Current | Recommended | Rationale |
|---------|---------|-------------|-----------|
| graph-primitives | 1 module | Keep 1 module | No constraint poisoning; algorithms are the value proposition |
| machine-primitives | 2 modules (Core + Conveniences) | Keep 2 modules | Adequate separation |
| parser-machine-primitives | 1 module | Keep 1 module | Single domain, tightly integrated |

**Findings**:

| ID | Package | Severity | Description | Status |
|----|---------|----------|-------------|--------|
| G-1 | graph | Critical | Generic `subgraph(inducedBy:using:)` creates sentinel nodes for edges pointing outside subgraph, violating documented invariant | RESOLVED — pre-validates all edges target included nodes, returns nil if not self-contained |
| G-2 | graph | Minor | `nodes` property chains mechanism-leaky lazy map | OPEN |
| G-3 | graph | Minor | swift-index-primitives dependency listed twice in Package.swift | OPEN |
| G-4 | graph | Minor | `Array<Int>.Fixed.Indexed<Tag>` with -1 sentinels in Tarjan SCC — principled departure from typed arithmetic for algorithm performance | OPEN |
| G-5 | graph | Minor | exports.swift lacks comment explaining non-exported algorithm dependencies | OPEN |
| M-1 | machine | Documented | Direct `captures.slots[raw.rawValue]` instead of `withRawThrowing` — compiler crash (signal 11) with nested typed throws; WORKAROUND per [PATTERN-016] | DEFERRED — revisit when Swift fixes nested typed throws in closure contexts |
| M-2 | machine | Minor | Intermediate `let table = _Table(T.self)` in Value.make() adds no explanatory value per [IMPL-EXPR-001] | OPEN |
| M-3 | machine | Minor | Only Mode.Reference convenience methods in Builder+Carriers; no Mode.Unchecked equivalents | OPEN |
| P-1 | parser-machine | Minor | Run function ~300 lines — mechanically correct but dense; helper extraction may prevent optimizer specialization of hot path | OPEN |
| P-2 | parser-machine | Minor | `current.rawValue` for memo key — only rawValue leak, confined to run loop, justified | OPEN |

**Patterns to preserve**: retag() over rawValue, closure-based witnesses, table-based type erasure, mode stratification via extension specialization, consuming builders, consistent accessor pattern (`graph.traverse`, `graph.analyze`, `program.apply`).

**Cross-references**: [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-002], [PATTERN-017], [API-IMPL-005], [PRIM-FOUND-001], [PATTERN-022]

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-machine-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=0, MEDIUM=1, LOW=7, INFO=3
Finding IDs: IMPL-002, IMPL-010, IMPL-020, IMPL-050, PATTERN-016, PATTERN-017, PATTERN-021

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| MACH-001 | MEDIUM | [API-NAME-002] | Machine.Builder+Carriers.swift | 33 | Compound method `throwingTransform` |
| MACH-002 | LOW | [PATTERN-017] | Machine.Capture.Frozen+Reference.swift | 8, 19, 30 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-003 | LOW | [PATTERN-017] | Machine.Capture.Frozen+Unchecked.swift | 8, 19, 30 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-004 | LOW | [PATTERN-017] | Machine.Capture.Store+Reference.swift | 19, 31, 43 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-005 | LOW | [PATTERN-017] | Machine.Capture.Store+Unchecked.swift | 18, 30, 42 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-006 | LOW | [PATTERN-017] | Machine.Transform.Throwing.swift | 40-41, 57-58 | Direct slot access via `captures.slots[raw.rawValue]` (documented workaround) |
| MACH-007 | LOW | [IMPL-010] | Machine.Value.Arena.swift | 53, 56, 77-78, 92-93, 96, 106 | `Int(slot)` conversions scattered through Arena methods |
| MACH-008 | LOW | [IMPL-010] | Machine.Value.Handle.swift | 51, 60 | `Int(slot)` / `UInt32(handle.index)` conversions in handle helpers |
| MACH-009 | INFO | [API-IMPL-005] | Machine.Capture.Slot.swift | 37-56 | `_Storage` class nested inside `Slot` struct (same file) |
| MACH-010 | INFO | [API-IMPL-005] | Machine.Value.swift | 51-67, 76-89, 137-150 | `_Storage`, `_Table`, `Ref` nested inside `Value` struct |
| MACH-011 | INFO | [API-NAME-001] | Machine.Value.Handle.swift | 19 | `_MachineValueArenaTag` — compound name, but underscore-prefixed internal phantom type |

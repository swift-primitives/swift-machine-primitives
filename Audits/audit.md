# Audit: swift-machine-primitives

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

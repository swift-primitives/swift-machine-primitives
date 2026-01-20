# Machine Primitives Insights

<!--
---
title: Machine Primitives Insights
version: 1.0.0
last_updated: 2026-01-20
applies_to: [swift-machine-primitives]
normative: false
---
-->

@Metadata {
    @TitleHeading("Machine Primitives")
}

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-machine-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-machine-primitives]`.

---

## The Discipline of Total Interpreters

**Date**: 2026-01-19

**Context**: Migrating swift-binary-primitives to share infrastructure from swift-machine-primitives via typealiases revealed the temptation to `fatalError` for cases the façade doesn't use.

When Binary's interpreter needed to handle `flatMap` (a case Binary doesn't construct today), the expedient choice was `fatalError("Binary.Bytes.Machine does not support flatMap")`. This approach is wrong for two reasons:

1. **Runtime traps in critical paths**: The interpreter runs inside `withBorrowed`, the critical path for zero-copy binary parsing. A trap here is catastrophic.

2. **Contract violation**: The core `Machine.Frame` has `flatMap` as a first-class case. Any interpreter over that frame type must handle all cases—not because it will encounter them today, but because the type system promises totality.

### Implementation Over Prohibition

The correct approach: implement `flatMap` fully (`current = next.next(value); continue`), even though no Binary combinator constructs it. The code path is dead today but safe. If someone later adds a `flatMap` combinator to Binary, it works. If no one does, the dead code costs nothing.

This is the opposite of defensive programming's "fail fast" mantra. In a total interpreter over a shared algebraic data type, "fail never" is the discipline. Prohibition belongs at the API boundary (don't expose a `flatMap` combinator if you don't want it), not in the interpreter.

### The `Never` Pattern

For truly uninhabited cases, Swift provides the perfect tool:

```swift
case .extra(let never): switch never {}
```

This is not a trap—it's a proof that the case cannot occur. The `switch never {}` compiles to nothing; it's the type system asserting impossibility. This pattern should be reflexive when `Extra = Never`.

**Applies to**: All interpreters over `Machine.Frame`, `Machine.Node`, and any shared algebraic data type with optional extension points.

---

## Topics

### Related Documents

- <doc:Machine>

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

## Sendability as Derived Truth, Not Policy

**Date**: 2026-01-19

**Context**: Discovering that `Transform.Erased` storing non-@Sendable closures blocks Sendability through the entire chain: Node → Program → Parser.

### The Temptation of Parallel Types

When a type needs to support both Sendable and non-Sendable use cases, the expedient design is two types: `SendableTransform` and `Transform`. This feels principled—each type has clear semantics.

But it's wrong. It encodes *policy* (whether this program is safe to share) into the *type family*, rather than deriving it from the *structure*. The result: parallel API surfaces, awkward conversions, and a decision point that doesn't need to exist.

### The Array Precedent

Swift's `Array<Element>` doesn't come in Sendable and NonSendable variants. There's one `Array`. It conforms to `Sendable` when `Element: Sendable`. The Sendability is *derived* from the generic parameter, not declared as a type-level fork.

This is the model: one type, conditional conformance, truth derived from structure.

### Application to Machine Primitives

The correct design for `Machine.Program` is one type generic over a capture store:

```swift
public struct Program<Leaf, Failure: Error, Captures: Machine.Capture.Store> { ... }

extension Program: Sendable
    where Leaf: Sendable, Failure: Sendable, Captures: Sendable {}
```

If you instantiate with a Sendable capture store, you get a Sendable program. No policy decision, no parallel types—just structural truth.

### The Principle

When designing types that may or may not satisfy a marker protocol (Sendable, Equatable, Hashable), prefer conditional conformance over type families. Let the structure speak.

**Applies to**: `Machine.Program`, `Machine.Node`, any type with variable Sendability requirements.

---

## The Closure-Free Machine Graph

**Date**: 2026-01-19

**Context**: Converging on a closure-free design for machine-primitives after evaluating alternatives.

### Why Closures Are the Problem

A closure in Swift is a function plus its captured environment. When you store a closure:

```swift
public struct Transform {
    public let apply: (Value) -> Value  // Captures arbitrary state
}
```

...you've stored not just a function, but whatever it captured. That capture might be Sendable or not. The type system can't see inside. The only way to enforce Sendability is to mark the closure `@Sendable`, which then requires all captures to be Sendable—breaking valid single-threaded use cases.

### The Split: Thunk + Explicit Capture

The solution separates what the closure conflates:

1. **The function logic**: A non-capturing static thunk that receives its "environment" as a parameter
2. **The captured data**: Explicit storage in a typed capture store, referenced by ID

```swift
public struct Transform<Store: Machine.Capture.Store> {
    public let captureID: Machine.Capture.ID
    public let apply: @Sendable (borrowing Store, Value) -> Value  // Non-capturing
}
```

Now `Transform` is always Sendable—it's just an ID and a function pointer. The Sendability of the *program* depends on whether the *capture store* is Sendable.

### The Cost

This is closure conversion done explicitly. Users writing `map { $0 + constant }` trigger machinery that captures `constant` into the store, returns an ID, and generates a thunk that retrieves the capture by ID.

The complexity is real but paid once in machine-primitives. Every consumer inherits truthful Sendability without escape hatches.

**Applies to**: `Machine.Transform`, `Machine.Combine`, `Machine.Finalize`, all closure-like types.

---

## Leaky Abstraction Detection via Generic Signatures

**Date**: 2026-01-19

**Context**: An initial design parameterized Program over `Box: AnyObject`, which was identified as a leaky abstraction.

### The Smell

```swift
public struct Program<Leaf, Failure: Error, Box: AnyObject> {
    public var captures: [Box]
}
```

This exposes implementation detail in the generic signature. `Box: AnyObject` says "captures are stored as an array of class instances." But why should consumers know this?

### The Correction

Parameterize by semantic abstraction, not implementation mechanism:

```swift
public struct Program<Leaf, Failure: Error, Captures: Machine.Capture.Store> {
    public var captures: Captures
}
```

Now `Captures` is an opaque store with an API contract. The storage strategy is hidden.

### The Detection Heuristic

When reviewing a generic type, ask: "Does this generic parameter name a *thing* or a *mechanism*?"

- `Element`, `Key`, `Value`, `Store` → things (good)
- `Box`, `Pointer`, `Array`, `Class` → mechanisms (suspicious)

Mechanism names suggest the abstraction is leaking. The generic should constrain *capability*, not *representation*.

**Applies to**: All generic type design in machine-primitives.

---

## The Program Graph as Pure Data

**Date**: 2026-01-19

**Context**: Reflecting on what the closure-free design achieves conceptually.

### Before: Program as Closure Soup

The original `Machine.Program` stored nodes containing closures:

```swift
case map(child: ID, transform: Transform.Erased)  // Transform.Erased stores a closure
```

The "program" was inseparable from its captured runtime environment. You couldn't inspect it, serialize it, or reason about whether sharing it was safe.

### After: Program as Data + Catalog

With the closure-free design:

```swift
case map(child: ID, transform: Transform<Store>)  // Transform stores an ID + function pointer
```

The program is now a graph of node descriptions plus a catalog of captured values. The graph is statically inspectable. The catalog's Sendability determines the program's Sendability.

### What This Enables

1. **Truthful Sendability**: No `@unchecked Sendable` lies. Sendability is structural.
2. **Serialization potential**: A program could be serialized if captures are Codable.
3. **Equality potential**: Two programs are equal if their graphs and captures are equal.
4. **Debuggability**: You can dump the capture store to see what a program "contains."

These aren't immediate features, but they're *possible* because the representation is data, not opaque closures.

**Applies to**: The entire `Machine.Program` architecture.

---

## Multi-LLM Convergence as Design Process

**Date**: 2026-01-19

**Context**: Working through the Sendability design with structured multi-LLM discussion (Claude and ChatGPT) facilitated by the user.

### The Process

The user presented a design question (how to make Parser Sendable) and facilitated a three-round discussion:

1. **Round 1**: Three positions presented. ChatGPT responded with corrections and preferences.
2. **Round 2**: Concrete architecture proposed. ChatGPT identified a leaky abstraction (`Box: AnyObject` in the generic signature).
3. **Round 3**: Converged on parameterizing by `Capture.Store` protocol.

Each round narrowed disagreement. The structured format—explicit positions, specific questions, concrete code examples—enabled genuine convergence.

### What Worked

Different models brought different strengths. ChatGPT's framing of "two semantic regimes" was clarifying. Claude's codebase exploration grounded abstract principles in concrete types. The synthesis was better than either alone.

### The Limitation

Neither model could *execute* the plan. The user must still implement. But the collaborative design phase produced a plan both models endorsed—a higher-confidence starting point.

### Applicability

This pattern works when:
- The problem has genuine design alternatives
- Different perspectives might surface different trade-offs
- A human can evaluate which model's reasoning is stronger per-point

**Applies to**: Complex design questions requiring exploration of trade-offs.

---

## Related

- Machine

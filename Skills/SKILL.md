---
name: machine-primitives
description: |
  State machine and parser combinator primitives.
  ALWAYS apply when working with parsers or state machines.

layer: implementation

requires:
  - primitives

applies_to:
  - swift
  - swift-primitives
  - swift-machine-primitives
---

# Machine Primitives

Closure-free parser combinators and state machines.

---

## Core Design Decisions

### [MCH-001] Closure-Free Combinators

**Statement**: Parser combinators MUST avoid closures for performance and ~Copyable support.

---

## Cross-References

Full analysis: `Research/Analysis - Closure-Free Parser Combinators.md`

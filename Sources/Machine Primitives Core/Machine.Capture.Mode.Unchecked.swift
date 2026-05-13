extension Machine.Capture.Mode {
    /// Capture mode that admits non-Sendable values into the capture store.
    ///
    /// This is the structural realization of region-based isolation per
    /// [MEM-SEND-013]: combinator factories built atop this mode drop their
    /// Sendable bounds (`<T: Sendable>`, `@Sendable` on stored closures),
    /// and consumers transport assembled programs across actors via
    /// `sending` parameters at the program-transport boundary — not via
    /// per-capture Sendable conformance.
    ///
    /// `Mode.Unchecked` is itself **not** `Sendable`. `Program`s and
    /// `Parser`s parameterized by this mode are non-Sendable; cross-isolation
    /// transport requires `sending` discipline at every transport site,
    /// rather than relying on a structural Sendable conformance on the
    /// assembled value.
    ///
    /// Contrast with `Mode.Reference`, which structurally enforces
    /// Sendable on every captured value and yields Sendable assembled
    /// programs at the cost of a `<T: Sendable>` bound on every combinator.
    public struct Unchecked {
        @usableFromInline
        init() {}
    }
}

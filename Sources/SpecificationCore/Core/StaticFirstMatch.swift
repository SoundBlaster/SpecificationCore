//
//  StaticFirstMatch.swift
//  SpecificationCore
//

/// A binary ordered decision composition used by `StaticFirstMatchBuilder`.
///
/// Evaluation asks the first decision for a result and evaluates the second only
/// when the first returns `nil`. The builder arranges these nodes as a balanced
/// tree while preserving left-to-right rule priority.
public struct BinaryFirstMatch<First: DecisionSpec, Second: DecisionSpec>: DecisionSpec
    where First.Context == Second.Context, First.Result == Second.Result
{
    public typealias Context = First.Context
    public typealias Result = First.Result

    @usableFromInline let first: First
    @usableFromInline let second: Second

    /// Creates an ordered pair of decision specifications.
    @inlinable
    public init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    // swiftformat:disable docComments
    /// Returns the first non-`nil` decision, preserving left-to-right priority.
    #if !Tracing
        @inlinable
    #endif
    public func decide(_ context: Context) -> Result? {
        #if Tracing
            return SpecificationTraceRuntime.withDecision("BinaryFirstMatch") {
                let firstResult = SpecificationTraceRuntime.decideChild(first, context, name: "first")
                if let firstResult {
                    if !SpecificationTraceRuntime.isExcluded(second) {
                        SpecificationTraceRuntime.skip("second")
                    }
                    return firstResult
                }
                return SpecificationTraceRuntime.decideChild(second, context, name: "second")
            }
        #else
            first.decide(context) ?? second.decide(context)
        #endif
    }
    // swiftformat:enable docComments
}

/// A result builder for ordered static decision rules.
///
/// The builder supports one through ten rules. It emits fixed-arity binary
/// compositions with logarithmic depth and preserves source order.
@resultBuilder
public enum StaticFirstMatchBuilder {
    @inlinable
    public static func buildBlock<A: DecisionSpec>(
        _ a: A
    ) -> A {
        a
    }

    @inlinable
    public static func buildBlock<A: DecisionSpec, B: DecisionSpec>(
        _ a: A,
        _ b: B
    ) -> BinaryFirstMatch<A, B>
        where B.Context == A.Context, B.Result == A.Result
    {
        BinaryFirstMatch(first: a, second: b)
    }

    @inlinable
    public static func buildBlock<A: DecisionSpec, B: DecisionSpec, C: DecisionSpec>(
        _ a: A,
        _ b: B,
        _ c: C
    ) -> BinaryFirstMatch<A, BinaryFirstMatch<B, C>>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result
    {
        BinaryFirstMatch(first: a, second: BinaryFirstMatch(first: b, second: c))
    }

    @inlinable
    public static func buildBlock<A: DecisionSpec, B: DecisionSpec, C: DecisionSpec, D: DecisionSpec>(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D
    ) -> BinaryFirstMatch<BinaryFirstMatch<A, B>, BinaryFirstMatch<C, D>>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result
    {
        BinaryFirstMatch(first: BinaryFirstMatch(first: a, second: b), second: BinaryFirstMatch(first: c, second: d))
    }

    @inlinable
    public static func buildBlock<A: DecisionSpec, B: DecisionSpec, C: DecisionSpec, D: DecisionSpec, E: DecisionSpec>(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E
    ) -> BinaryFirstMatch<BinaryFirstMatch<A, B>, BinaryFirstMatch<C, BinaryFirstMatch<D, E>>>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: a, second: b),
            second: BinaryFirstMatch(first: c, second: BinaryFirstMatch(first: d, second: e))
        )
    }

    @inlinable
    public static func buildBlock<
        A: DecisionSpec,
        B: DecisionSpec,
        C: DecisionSpec,
        D: DecisionSpec,
        E: DecisionSpec,
        F: DecisionSpec
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F
    ) -> BinaryFirstMatch<BinaryFirstMatch<A, BinaryFirstMatch<B, C>>, BinaryFirstMatch<D, BinaryFirstMatch<E, F>>>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result,
        F.Context == A.Context, F.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: a, second: BinaryFirstMatch(first: b, second: c)),
            second: BinaryFirstMatch(first: d, second: BinaryFirstMatch(first: e, second: f))
        )
    }

    @inlinable
    public static func buildBlock<
        A: DecisionSpec,
        B: DecisionSpec,
        C: DecisionSpec,
        D: DecisionSpec,
        E: DecisionSpec,
        F: DecisionSpec,
        G: DecisionSpec
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F,
        _ g: G
    ) -> BinaryFirstMatch<BinaryFirstMatch<A, BinaryFirstMatch<B, C>>, BinaryFirstMatch<
        BinaryFirstMatch<D, E>,
        BinaryFirstMatch<F, G>
    >>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result,
        F.Context == A.Context, F.Result == A.Result,
        G.Context == A.Context, G.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: a, second: BinaryFirstMatch(first: b, second: c)),
            second: BinaryFirstMatch(
                first: BinaryFirstMatch(first: d, second: e),
                second: BinaryFirstMatch(first: f, second: g)
            )
        )
    }

    @inlinable
    public static func buildBlock<
        A: DecisionSpec,
        B: DecisionSpec,
        C: DecisionSpec,
        D: DecisionSpec,
        E: DecisionSpec,
        F: DecisionSpec,
        G: DecisionSpec,
        H: DecisionSpec
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F,
        _ g: G,
        _ h: H
    ) -> BinaryFirstMatch<BinaryFirstMatch<BinaryFirstMatch<A, B>, BinaryFirstMatch<C, D>>, BinaryFirstMatch<
        BinaryFirstMatch<E, F>,
        BinaryFirstMatch<G, H>
    >>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result,
        F.Context == A.Context, F.Result == A.Result,
        G.Context == A.Context, G.Result == A.Result,
        H.Context == A.Context, H.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: BinaryFirstMatch(first: a, second: b), second: BinaryFirstMatch(
                first: c,
                second: d
            )),
            second: BinaryFirstMatch(
                first: BinaryFirstMatch(first: e, second: f),
                second: BinaryFirstMatch(first: g, second: h)
            )
        )
    }

    @inlinable
    public static func buildBlock<
        A: DecisionSpec,
        B: DecisionSpec,
        C: DecisionSpec,
        D: DecisionSpec,
        E: DecisionSpec,
        F: DecisionSpec,
        G: DecisionSpec,
        H: DecisionSpec,
        I: DecisionSpec
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F,
        _ g: G,
        _ h: H,
        _ i: I
    ) -> BinaryFirstMatch<BinaryFirstMatch<BinaryFirstMatch<A, B>, BinaryFirstMatch<C, D>>, BinaryFirstMatch<
        BinaryFirstMatch<E, F>,
        BinaryFirstMatch<G, BinaryFirstMatch<H, I>>
    >>
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result,
        F.Context == A.Context, F.Result == A.Result,
        G.Context == A.Context, G.Result == A.Result,
        H.Context == A.Context, H.Result == A.Result,
        I.Context == A.Context, I.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: BinaryFirstMatch(first: a, second: b), second: BinaryFirstMatch(
                first: c,
                second: d
            )),
            second: BinaryFirstMatch(
                first: BinaryFirstMatch(first: e, second: f),
                second: BinaryFirstMatch(first: g, second: BinaryFirstMatch(first: h, second: i))
            )
        )
    }

    @inlinable
    public static func buildBlock<
        A: DecisionSpec,
        B: DecisionSpec,
        C: DecisionSpec,
        D: DecisionSpec,
        E: DecisionSpec,
        F: DecisionSpec,
        G: DecisionSpec,
        H: DecisionSpec,
        I: DecisionSpec,
        J: DecisionSpec
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F,
        _ g: G,
        _ h: H,
        _ i: I,
        _ j: J
    )
        -> BinaryFirstMatch<
            BinaryFirstMatch<BinaryFirstMatch<A, B>, BinaryFirstMatch<C, BinaryFirstMatch<D, E>>>,
            BinaryFirstMatch<
                BinaryFirstMatch<F, G>,
                BinaryFirstMatch<H, BinaryFirstMatch<I, J>>
            >
        >
        where B.Context == A.Context, B.Result == A.Result,
        C.Context == A.Context, C.Result == A.Result,
        D.Context == A.Context, D.Result == A.Result,
        E.Context == A.Context, E.Result == A.Result,
        F.Context == A.Context, F.Result == A.Result,
        G.Context == A.Context, G.Result == A.Result,
        H.Context == A.Context, H.Result == A.Result,
        I.Context == A.Context, I.Result == A.Result,
        J.Context == A.Context, J.Result == A.Result
    {
        BinaryFirstMatch(
            first: BinaryFirstMatch(first: BinaryFirstMatch(first: a, second: b), second: BinaryFirstMatch(
                first: c,
                second: BinaryFirstMatch(first: d, second: e)
            )),
            second: BinaryFirstMatch(
                first: BinaryFirstMatch(first: f, second: g),
                second: BinaryFirstMatch(first: h, second: BinaryFirstMatch(first: i, second: j))
            )
        )
    }
}

/// A first-match decision whose rules are composed into a balanced static tree.
///
/// Use `StaticFirstMatch` when a fixed rule set should remain fully typed and
/// should be evaluated without an existential collection.
public struct StaticFirstMatch<Rules: DecisionSpec>: DecisionSpec {
    public typealias Context = Rules.Context
    public typealias Result = Rules.Result

    @usableFromInline let rules: Rules

    /// Builds a static first-match decision from one through ten ordered rules.
    @inlinable
    public init(@StaticFirstMatchBuilder _ buildRules: () -> Rules) {
        rules = buildRules()
    }

    // swiftformat:disable docComments
    /// Returns the first non-`nil` decision in builder order.
    #if !Tracing
        @inlinable
    #endif
    public func decide(_ context: Context) -> Result? {
        #if Tracing
            return SpecificationTraceRuntime.withDecision("StaticFirstMatch") {
                SpecificationTraceRuntime.decideChild(rules, context, name: "rules")
            }
        #else
            rules.decide(context)
        #endif
    }
    // swiftformat:enable docComments
}

extension BinaryFirstMatch: Sendable where First: Sendable, Second: Sendable {}
extension StaticFirstMatch: Sendable where Rules: Sendable {}

#if Tracing
    extension BinaryFirstMatch: SpecificationTraceExclusion {
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(first) && SpecificationTraceRuntime.isExcluded(second)
        }
    }

    extension StaticFirstMatch: SpecificationTraceExclusion {
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(rules)
        }
    }
#endif

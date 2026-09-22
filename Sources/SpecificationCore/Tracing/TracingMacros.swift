//
// TracingMacros.swift
// SpecificationCore
//

#if Tracing
    /// Instruments the supported evaluation methods on a user-defined specification.
    ///
    /// The name should be a stable identifier suitable for tracing systems, such as
    /// `"checkout.cart.eligible"`.
    /// Supported methods are `isSatisfiedBy(_:)` and `decide(_:)`, including async
    /// throwing variants. Events are emitted when a default recorder or explicit
    /// trace scope is active.
    /// See <doc:Tracing> for setup and examples.
    @attached(memberAttribute)
    public macro TracedSpecification(_ name: String) =
        #externalMacro(module: "SpecificationCoreMacros", type: "TracedSpecificationMacro")

    /// Adds a trace span around one specification evaluation method.
    ///
    /// Supported methods are `isSatisfiedBy(_:)` and `decide(_:)`, including async
    /// throwing variants. The method's result and error behavior are preserved.
    /// Events are emitted when a default recorder or explicit trace scope is
    /// active. See <doc:Tracing>.
    @attached(body)
    public macro TraceEvaluation(_ name: String) =
        #externalMacro(module: "SpecificationCoreMacros", type: "TraceEvaluationMacro")
#endif

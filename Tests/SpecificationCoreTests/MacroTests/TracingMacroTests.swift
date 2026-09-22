@testable import SpecificationCoreMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class TracingMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "TracedSpecification": TracedSpecificationMacro.self,
        "TraceEvaluation": TraceEvaluationMacro.self
    ]

    func testTypeMacroAddsAndExpandsTraceForBooleanSpecification() {
        assertMacroExpansion(
            """
            @TracedSpecification("catalog.available")
            struct CatalogSpec {
                func isSatisfiedBy(_ value: String) -> Bool {
                    value == "available"
                }
            }
            """,
            expandedSource: """
            struct CatalogSpec {
                func isSatisfiedBy(_ value: String) -> Bool {
                    return SpecificationTraceRuntime.withBoolean("catalog.available") { () -> Bool in
                        value == "available"
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testBodyMacroWrapsAsyncBooleanAndDecisionMethods() {
        assertMacroExpansion(
            """
            struct AsyncCatalogSpec {
                @TraceEvaluation("catalog.async-available")
                func isSatisfiedBy(_ value: String) async throws -> Bool {
                    try await check(value)
                }

                @TraceEvaluation("catalog.decision")
                func decide(_ value: String) async throws -> String? {
                    try await lookup(value)
                }
            }
            """,
            expandedSource: """
            struct AsyncCatalogSpec {
                func isSatisfiedBy(_ value: String) async throws -> Bool {
                    return try await SpecificationTraceRuntime.withBoolean("catalog.async-available") { () async throws -> Bool in
                        try await check(value)
                    }
                }
                func decide(_ value: String) async throws -> String? {
                    return try await SpecificationTraceRuntime.withDecision("catalog.decision") { () async throws -> String? in
                        try await lookup(value)
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testBodyMacroPreservesNonthrowingAsyncSignature() {
        assertMacroExpansion(
            """
            struct AsyncNonthrowingCatalogSpec {
                @TraceEvaluation("catalog.nonthrowing-available")
                func isSatisfiedBy(_ value: String) async -> Bool {
                    await check(value)
                }
            }
            """,
            expandedSource: """
            struct AsyncNonthrowingCatalogSpec {
                func isSatisfiedBy(_ value: String) async -> Bool {
                    return await SpecificationTraceRuntime.withBoolean("catalog.nonthrowing-available") { () async -> Bool in
                        await check(value)
                    }
                }
            }
            """,
            macros: macros
        )
    }
}

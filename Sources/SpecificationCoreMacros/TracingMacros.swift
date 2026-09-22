import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Attaches `@TraceEvaluation` to supported specification evaluation methods.
public struct TracedSpecificationMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let function = member.as(FunctionDeclSyntax.self),
              ["isSatisfiedBy", "decide"].contains(function.name.text),
              let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let name = arguments.first?.expression
        else {
            return []
        }

        let alreadyTraced = function.attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            return attribute.attributeName.trimmedDescription == "TraceEvaluation"
        }
        guard !alreadyTraced else { return [] }

        return ["@TraceEvaluation(\(name))"]
    }
}

/// Wraps an evaluation method's original body in the corresponding runtime span.
public struct TraceEvaluationMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self),
              let originalBody = function.body,
              ["isSatisfiedBy", "decide"].contains(function.name.text),
              let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let name = arguments.first?.expression
        else {
            return []
        }

        let operation: String
        let async = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let throwing = function.signature.effectSpecifiers?.throwsSpecifier != nil
        if function.name.text == "decide" {
            operation = "withDecision"
        } else {
            operation = "withBoolean"
        }

        let resultType = function.signature.returnClause?.type.trimmedDescription ?? "Bool"
        let callPrefix = async ? (throwing ? "try await " : "await ") : ""
        let closureEffects = async ? (throwing ? " async throws" : " async") : ""
        let statements = originalBody.statements
            .map(\.trimmedDescription)
            .joined(separator: "\n")
        let source = "return \(callPrefix)SpecificationTraceRuntime.\(operation)(\(name.trimmedDescription)) "
            + "{ ()\(closureEffects) -> \(resultType) in\n\(statements)\n}"

        return [CodeBlockItemSyntax(stringLiteral: source)]
    }
}

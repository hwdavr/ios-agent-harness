import SwiftSyntax

struct LocalizationRuleChecker {
    let context: CheckerContext

    func check(_ source: ParsedSource) -> [Diagnostic] {
        let visitor = Visitor(source: source, context: context)
        visitor.walk(source.tree)
        return visitor.finish()
    }

    private final class Visitor: RuleVisitor {
        let context: CheckerContext
        private let userVisibleFunctions: Set<String> = ["Text", "Label", "Button", "TextField", "ProgressView"]
        private let userVisibleModifiers: Set<String> = [
            "navigationTitle", "alert", "confirmationDialog",
            "accessibilityLabel", "accessibilityHint", "accessibilityValue"
        ]
        private let appOwnedDirectories = ["Domain", "ViewModels", "Views", "Data"]
        private let rawCodeLanguageDirectories = ["Views", "ViewModels"]

        init(source: ParsedSource, context: CheckerContext) {
            self.context = context
            super.init(source: source)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let call = node.as(FunctionCallExprSyntax.self) {
                checkCall(call)
            }
            if let literal = node.as(StringLiteralExprSyntax.self) {
                checkAppOwnedLiteral(literal)
            }
            if let variable = node.as(VariableDeclSyntax.self) {
                checkNamedConstant(variable)
            }
            if let returnStatement = node.as(ReturnStmtSyntax.self) {
                checkReturnLiteral(returnStatement)
            }
            return .visitChildren
        }

        private func checkCall(_ call: FunctionCallExprSyntax) {
            let name = calledName(call)
            let firstArgument = call.arguments.first
            let literal = firstArgument?.expression.as(StringLiteralExprSyntax.self)

            if name == "NSLocalizedString" {
                report(
                    rule: "L10N",
                    node: call,
                    message: "NSLocalizedString is not allowed; use a catalog key with String(localized:)"
                )
            }

            if name == "String", firstArgument?.label?.text == "localized", let literal {
                checkResourceLiteral(literal, node: call)
            }
            if name == "LocalizedStringKey", let literal {
                checkResourceLiteral(literal, node: call)
            }

            if let name, userVisibleFunctions.contains(name), sourceIsIn(source, directory: "Views"), let literal {
                checkUserVisibleLiteral(literal, node: call)
            }
            if let name, userVisibleModifiers.contains(name), sourceIsIn(source, directory: "Views"), let literal {
                checkUserVisibleLiteral(literal, node: call)
            }

            if name == "accessibilityLabel",
               firstArgument?.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "rawValue" {
                report(
                    rule: "L10N",
                    node: call,
                    message: "accessibility category labels must use localized copy, not rawValue"
                )
            }

            if let name,
               ["invalid", "error", "network", "invalidCallback", "tokenExchangeFailed", "loginFailed", "shareFailed"]
                .contains(name),
               let messageArgument = call.arguments.first(where: { $0.label?.text == "message" }),
               let messageLiteral = messageArgument.expression.as(StringLiteralExprSyntax.self),
               isCapitalizedLiteral(messageLiteral) {
                report(
                    rule: "L10N",
                    node: messageLiteral,
                    message: "app-owned error message must come from a localization resource"
                )
            }
        }

        private func checkResourceLiteral(_ literal: StringLiteralExprSyntax, node: some SyntaxProtocol) {
            let key = hasStringInterpolation(literal) ? literalSourceValue(literal) : literalValue(literal)
            guard !key.isEmpty else { return }
            guard isValidLocalizationKey(key) else {
                report(rule: "L10N", node: node, message: "localization resource must use a prefixed key: \"\(key)\"")
                return
            }
            guard context.catalog?.hasKey(key) == true else {
                report(
                    rule: "L10N",
                    node: node,
                    message: "localization key is missing from Localizable.xcstrings: \"\(keyBase(key))\""
                )
                return
            }
        }

        private func checkUserVisibleLiteral(_ literal: StringLiteralExprSyntax, node: some SyntaxProtocol) {
            let interpolated = hasStringInterpolation(literal)
            let key = interpolated ? literalSourceValue(literal) : literalValue(literal)
            if key.isEmpty || (interpolated && key.hasPrefix("\\(") && !key.contains("%")) { return }
            guard isValidLocalizationKey(key) else {
                report(
                    rule: "L10N",
                    node: node,
                    message: "SwiftUI user-visible literal must use a prefixed localization key: \"\(key)\""
                )
                return
            }
            guard context.catalog?.hasKey(key) == true else {
                report(
                    rule: "L10N",
                    node: node,
                    message: "SwiftUI localization key is missing from Localizable.xcstrings: \"\(keyBase(key))\""
                )
                return
            }
        }

        private func checkAppOwnedLiteral(_ literal: StringLiteralExprSyntax) {
            guard appOwnedDirectories.contains(where: { sourceIsIn(source, directory: $0) }) else { return }
            let value = literalValue(literal)
            if value == "Plain Text",
               rawCodeLanguageDirectories.contains(where: { sourceIsIn(source, directory: $0) }) {
                report(rule: "L10N", node: literal, message: "raw code-language label must use a localization resource")
                return
            }

            guard isCapitalizedLiteral(literal) else { return }
            if hasAncestor(literal._syntaxNode, matching: { ancestor in
                guard let call = ancestor.as(FunctionCallExprSyntax.self) else { return false }
                return ["invalidCallback", "tokenExchangeFailed", "loginFailed", "shareFailed"]
                    .contains(calledName(call))
            }) {
                report(
                    rule: "L10N",
                    node: literal,
                    message: "app-owned error message must come from a localization resource"
                )
            }
        }

        private func checkNamedConstant(_ variable: VariableDeclSyntax) {
            guard appOwnedDirectories.contains(where: { sourceIsIn(source, directory: $0) }) else { return }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      identifier.hasSuffix("Title") || identifier.hasSuffix("Label") ||
                      identifier.hasSuffix("Message") ||
                      identifier.hasSuffix("Placeholder") || identifier.hasSuffix("Description") ||
                      identifier.hasSuffix("Error"),
                      let literal = binding.initializer?.value.as(StringLiteralExprSyntax.self),
                      isCapitalizedLiteral(literal) else { continue }
                report(
                    rule: "L10N",
                    node: literal,
                    message: "app-owned error message must come from a localization resource"
                )
            }
        }

        private func checkReturnLiteral(_ statement: ReturnStmtSyntax) {
            guard appOwnedDirectories.contains(where: { sourceIsIn(source, directory: $0) }),
                  let literal = statement.expression?.as(StringLiteralExprSyntax.self),
                  isCapitalizedSentence(literal) else { return }
            report(
                rule: "L10N",
                node: literal,
                message: "app-owned error message must come from a localization resource"
            )
        }

        private func isCapitalizedSentence(_ literal: StringLiteralExprSyntax) -> Bool {
            literalValue(literal).first?.isUppercase == true &&
                literalValue(literal).last.map { ".!?".contains($0) } == true
        }

        private func keyBase(_ key: String) -> String {
            key.split(separator: " ", maxSplits: 1).first.map(String.init) ?? key
        }

        private func isCapitalizedLiteral(_ literal: StringLiteralExprSyntax) -> Bool {
            literalValue(literal).first?.isUppercase == true
        }
    }
}

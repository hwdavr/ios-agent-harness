import SwiftSyntax

struct SwiftUIRuleChecker {
    let context: CheckerContext

    func check(_ source: ParsedSource) -> [Diagnostic] {
        let visitor = Visitor(source: source, context: context)
        visitor.walk(source.tree)
        return visitor.finish()
    }

    private final class Visitor: RuleVisitor {
        let context: CheckerContext
        private let interactiveTypes: Set<String> = [
            "Button", "TextField", "Toggle", "Picker", "Stepper", "Slider", "SecureField", "TextEditor", "List"
        ]
        private var interactiveElements: [(String, Syntax)] = []
        private var hasAccessibilityIdentifierModifier = false

        init(source: ParsedSource, context: CheckerContext) {
            self.context = context
            super.init(source: source)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let call = node.as(FunctionCallExprSyntax.self), calledName(call) == "accessibilityIdentifier" {
                checkDynamicAccessibility(Syntax(call))
            }
            guard sourceIsIn(source, directory: "Views") else { return .visitChildren }
            guard let call = node.as(FunctionCallExprSyntax.self) else {
                checkHardCodedMember(node)
                return .visitChildren
            }

            let name = calledName(call)
            if let name, interactiveTypes.contains(name) {
                interactiveElements.append((name, node))
            }
            if name == "accessibilityIdentifier" {
                hasAccessibilityIdentifierModifier = true
            }

            if name == "Color",
               call.arguments.contains(where: { ["red", "green", "blue", "hex"].contains($0.label?.text) }) {
                report(rule: "SUI", node: call, message: "Hardcoded Color literal")
            }

            if let name, ["Text", "Label", "Button", "TextField", "ProgressView"].contains(name),
               let literal = call.arguments.first?.expression.as(StringLiteralExprSyntax.self),
               literalValue(literal).first?.isUppercase == true {
                report(rule: "SUI", node: literal, message: "Hardcoded string in Text()")
            }

            if name == "VStack", !call.trimmedDescription.contains("\n"),
               containsFunctionCall(Syntax(call), named: "ForEach") {
                report(rule: "SUI", node: call, message: "VStack with ForEach (use List or LazyVStack)")
            }

            if let base = memberBaseName(call), base == "viewModel",
               hasAncestor(node, matching: { ancestor in
                   guard let declaration = ancestor.as(StructDeclSyntax.self) else { return false }
                   return declaration.name.text.hasSuffix("Content")
               }) {
                report(rule: "SUI", node: call, message: "Content View calling ViewModel directly")
            }

            return .visitChildren
        }

        override func finish() -> [Diagnostic] {
            if !interactiveElements.isEmpty, !hasAccessibilityIdentifierModifier,
               let (name, node) = interactiveElements.first {
                report(
                    rule: "SUI",
                    node: node,
                    message: "Interactive element '\(name)' is missing accessibilityIdentifier"
                )
            }
            return super.finish()
        }

        private func checkHardCodedMember(_ node: Syntax) {
            guard let member = node.as(MemberAccessExprSyntax.self) else { return }
            let name = member.declName.baseName.text
            if ["red", "blue", "green"].contains(name) {
                report(rule: "SUI", node: member, message: "Hardcoded Color literal")
            }
        }

        private func checkDynamicAccessibility(_ node: Syntax) {
            guard let call = node.as(FunctionCallExprSyntax.self),
                  calledName(call) == "accessibilityIdentifier",
                  let literal = call.arguments.first?.expression.as(StringLiteralExprSyntax.self),
                  hasStringInterpolation(literal) else { return }

            let relativePath: String
            if source.path.hasPrefix(context.projectRoot + "/") {
                relativePath = String(source.path.dropFirst(context.projectRoot.count + 1))
            } else {
                relativePath = source.path
            }

            guard let registry = context.registry,
                  registry.matches(relativeFile: relativePath, sourceLine: call.trimmedDescription) else {
                report(
                    rule: "SUI",
                    node: call,
                    message: "dynamic accessibilityIdentifier is not an approved registered immutable identifier"
                )
                return
            }
        }
    }
}

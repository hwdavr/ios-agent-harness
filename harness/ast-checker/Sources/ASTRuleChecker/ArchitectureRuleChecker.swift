import SwiftSyntax

struct ArchitectureRuleChecker {
    let context: CheckerContext

    func check(_ source: ParsedSource) -> [Diagnostic] {
        let visitor = Visitor(source: source, context: context)
        visitor.walk(source.tree)
        return visitor.finish()
    }

    private final class Visitor: RuleVisitor {
        let context: CheckerContext

        init(source: ParsedSource, context: CheckerContext) {
            self.context = context
            super.init(source: source)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let importDecl = node.as(ImportDeclSyntax.self) {
                checkImport(importDecl)
            }

            if let reference = node.as(DeclReferenceExprSyntax.self),
               reference.baseName.text == "URLSession",
               sourceIsIn(source, directory: "ViewModels") {
                report(
                    rule: "ARCH",
                    node: reference,
                    message: "ViewModel imports URLSession directly"
                )
            }

            checkCodableDeclaration(node)
            checkViewBusinessLogic(node)
            return .visitChildren
        }

        private func checkImport(_ importDecl: ImportDeclSyntax) {
            let module = importDecl.path.trimmedDescription
            if sourceIsIn(source, directory: "Views"),
               module.contains("Data") || module == "URLSession" {
                report(
                    rule: "ARCH",
                    node: importDecl,
                    message: "SwiftUI View importing Data layer types"
                )
            }

            if sourceIsIn(source, directory: "Domain"), module == "SwiftUI" || module == "UIKit" {
                report(
                    rule: "ARCH",
                    node: importDecl,
                    message: "Domain file importing SwiftUI/UIKit"
                )
            }
        }

        private func checkCodableDeclaration(_ node: Syntax) {
            guard sourceIsIn(source, directory: "ViewModels") else { return }
            guard let declaration = node.as(DeclSyntax.self) else { return }
            guard inheritedNames(declaration).contains(where: { $0 == "Codable" || $0.hasSuffix(".Codable") }) else {
                return
            }
            report(
                rule: "ARCH",
                node: declaration,
                message: "ViewModel likely references DTO (Codable)"
            )
        }

        private func checkViewBusinessLogic(_ node: Syntax) {
            guard sourceIsIn(source, directory: "Views"),
                  let variable = node.as(VariableDeclSyntax.self),
                  variable.bindings.contains(where: { $0.pattern.trimmedDescription == "body" }) else {
                return
            }
            let hasEnabledAccess = containsIdentifier(Syntax(variable), named: "isEnabled")
            let hasStatusSwitch = containsStatusSwitch(Syntax(variable))
            guard hasEnabledAccess || hasStatusSwitch else { return }
            report(
                rule: "ARCH",
                node: variable,
                message: "Business logic in View body"
            )
        }

        private func containsStatusSwitch(_ node: Syntax) -> Bool {
            let finder = StatusSwitchFinder()
            finder.walk(node)
            return finder.found
        }
    }
}

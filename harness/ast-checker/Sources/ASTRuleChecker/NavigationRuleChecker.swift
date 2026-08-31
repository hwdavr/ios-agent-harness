import SwiftSyntax

struct NavigationRuleChecker {
    let context: CheckerContext

    func check(_ source: ParsedSource) -> [Diagnostic] {
        let visitor = Visitor(source: source, context: context)
        visitor.walk(source.tree)
        return visitor.finishNavigation()
    }

    private final class Visitor: RuleVisitor {
        let context: CheckerContext
        private var isMainNavigationFile = false
        private var hasTypedRootContainer = false
        private var hasTypedDestination = false
        private var foundPersistentRouteState = false

        init(source: ParsedSource, context: CheckerContext) {
            self.context = context
            isMainNavigationFile = source.path.hasSuffix("/Views/Main/MainTabView.swift")
            foundPersistentRouteState = [
                "activeDestination", "navigationPath", "navigationRoute", "currentRoute"
            ].contains {
                containsVariableDeclaration(Syntax(source.tree), named: $0)
            }
            super.init(source: source)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let declaration = node.as(EnumDeclSyntax.self),
               declaration.name.text.hasSuffix("Route") || declaration.name.text.hasSuffix("Destination") {
                checkRouteDeclaration(declaration)
            }
            if let parameter = node.as(EnumCaseParameterSyntax.self) {
                checkRouteParameter(parameter)
            }
            if let call = node.as(FunctionCallExprSyntax.self) {
                checkNavigationCall(call)
            }
            if let condition = node.as(OptionalBindingConditionSyntax.self) {
                checkConditionalDestination(condition)
            }
            if let variable = node.as(VariableDeclSyntax.self), sourceIsIn(source, directory: "ViewModels") {
                checkViewModelRouteState(variable)
            }
            if let function = node.as(FunctionDeclSyntax.self), sourceIsIn(source, directory: "ViewModels") {
                checkAuthExit(function)
            }
            if let nodeKind = node.as(StructDeclSyntax.self),
               isMainNavigationFile,
               nodeKind.name.text == "MainTabView" {
                checkRootDeclaration(nodeKind)
            }
            return .visitChildren
        }

        func finishNavigation() -> [Diagnostic] {
            if isMainNavigationFile {
                if !hasTypedRootContainer {
                    report(
                        rule: "NAV",
                        node: source.tree,
                        message: "root screen must define NavigationStack or NavigationSplitView"
                    )
                }
                if !hasTypedDestination {
                    report(
                        rule: "NAV",
                        node: source.tree,
                        message: "root navigation must handle typed routes with navigationDestination(for:)"
                    )
                }
            }
            return finish()
        }

        private func checkRootDeclaration(_ declaration: StructDeclSyntax) {
            hasTypedRootContainer = containsFunctionCall(Syntax(declaration.memberBlock), named: "NavigationStack") ||
                containsFunctionCall(Syntax(declaration.memberBlock), named: "NavigationSplitView")
        }

        private func checkNavigationCall(_ call: FunctionCallExprSyntax) {
            guard sourceIsIn(source, directory: "Views") else { return }
            if calledName(call) == "NavigationLink",
               call.arguments.contains(where: { $0.label?.text == "destination" }) {
                report(
                    rule: "NAV",
                    node: call,
                    message: "use NavigationLink(value:) with a Hashable route instead of NavigationLink(destination:)"
                )
            }
            if calledName(call) == "navigationDestination",
               isMainNavigationFile,
               call.arguments.contains(where: { $0.label?.text == "for" }) {
                hasTypedDestination = true
            }
        }

        private func checkConditionalDestination(_ condition: OptionalBindingConditionSyntax) {
            guard isMainNavigationFile,
                  let expression = condition.initializer?.value,
                  expression.trimmedDescription.contains("activeDestination") ||
                  expression.trimmedDescription.contains("navigationDestination") else {
                return
            }
            report(
                rule: "NAV",
                node: condition,
                message: "do not conditionally replace the root with a destination; " +
                    "push a typed route onto the navigation stack"
            )
        }

        private func checkRouteDeclaration(_ declaration: EnumDeclSyntax) {
            guard !inheritedNames(declaration).contains(where: { $0 == "Hashable" || $0.hasSuffix(".Hashable") }) else {
                return
            }
            report(rule: "NAV", node: declaration, message: "route/destination enums must conform to Hashable")
        }

        private func checkRouteParameter(_ parameter: EnumCaseParameterSyntax) {
            guard let route = nearestRouteEnum(from: Syntax(parameter)) else { return }
            let type = parameter.type.trimmedDescription
            if type.contains("?") && !context.hasNavigationDefaultValue {
                report(
                    rule: "NAV",
                    node: parameter,
                    message: "optional route arguments require an explicit defaultValue in the destination"
                )
            }
            let normalized = type.replacingOccurrences(of: "?", with: "")
            if normalized.hasSuffix("Model") || normalized.hasSuffix("DTO") || normalized.hasSuffix("Entity") ||
               !isHashableType(normalized, route: route) {
                let label = parameter.firstName?.text ?? parameter.secondName?.text ?? "argument"
                report(
                    rule: "NAV",
                    node: parameter,
                    message: "route argument '\(label)' uses non-Hashable or complex type '\(normalized)'; " +
                        "pass an ID or scalar value"
                )
            }
        }

        private func nearestRouteEnum(from node: Syntax) -> EnumDeclSyntax? {
            var current: Syntax? = node.parent
            while let candidate = current {
                if let declaration = candidate.as(EnumDeclSyntax.self),
                   declaration.name.text.hasSuffix("Route") || declaration.name.text.hasSuffix("Destination") {
                    return declaration
                }
                current = candidate.parent
            }
            return nil
        }

        private func isHashableType(_ type: String, route: EnumDeclSyntax) -> Bool {
            let primitives = Set([
                "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32",
                "UInt64", "Double", "Float", "Bool", "UUID", "Date", "URL"
            ])
            if primitives.contains(type) || context.hashableTypes.contains(type) { return true }
            let finder = HashableTypeFinder(name: type)
            finder.walk(source.tree)
            return finder.found
        }

        private func checkViewModelRouteState(_ variable: VariableDeclSyntax) {
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    continue
                }
                let isBooleanDestination = (identifier.hasPrefix("isShowing") || identifier.hasPrefix("showing") ||
                    identifier.hasPrefix("show")) &&
                    ["Editor", "Detail", "Screen", "Destination", "View"].contains(where: { identifier.hasSuffix($0) })
                let isRoute = ["activeDestination", "navigationPath", "navigationRoute", "currentRoute"]
                    .contains(identifier)
                guard isBooleanDestination || isRoute else { continue }
                if isRoute {
                    foundPersistentRouteState = true
                }
                report(
                    rule: "NAV",
                    node: variable,
                    message: isBooleanDestination
                        ? "do not encode a navigation destination as a boolean ViewModel flag"
                        : "navigation destinations belong to the View stack/path, not persistent ViewModel route state"
                )
            }
        }

        private func checkAuthExit(_ function: FunctionDeclSyntax) {
            guard foundPersistentRouteState,
                  ["signOut", "handleSessionExpired"].contains(function.name.text),
                  let body = function.body,
                  !containsClearOperation(Syntax(body)) else { return }
            report(
                rule: "NAV",
                node: function,
                message: "\(function.name.text) auth exit path must clear the navigation route/path"
            )
        }

        private func containsClearOperation(_ node: Syntax) -> Bool {
            let finder = NavigationClearFinder()
            finder.walk(node)
            return finder.found
        }
    }
}

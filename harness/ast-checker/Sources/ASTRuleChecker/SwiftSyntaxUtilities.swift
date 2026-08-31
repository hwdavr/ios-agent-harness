import SwiftSyntax

final class StatusSwitchFinder: SyntaxAnyVisitor {
    var found = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        guard let switchExpression = node.as(SwitchExprSyntax.self) else { return .visitChildren }
        if containsIdentifier(Syntax(switchExpression.subject), named: "status") {
            found = true
            return .skipChildren
        }
        return .visitChildren
    }
}

final class HashableTypeFinder: SyntaxAnyVisitor {
    let name: String
    var found = false

    init(name: String) {
        self.name = name
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let declaration = node.as(EnumDeclSyntax.self), declaration.name.text == name,
           inheritedNames(declaration).contains("Hashable") {
            found = true
        }
        if let declaration = node.as(StructDeclSyntax.self), declaration.name.text == name,
           inheritedNames(declaration).contains("Hashable") {
            found = true
        }
        return found ? .skipChildren : .visitChildren
    }
}

final class NavigationClearFinder: SyntaxAnyVisitor {
    var found = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let call = node.as(FunctionCallExprSyntax.self),
           ["removeLast", "removeAll"].contains(calledName(call)),
           memberBaseName(call) == "navigationPath" {
            found = true
            return .skipChildren
        }
        if node.kind == .sequenceExpr {
            let text = node.trimmedDescription
            if text.contains("activeDestination = nil") || text.contains("navigationPath = []") {
                found = true
                return .skipChildren
            }
        }
        return .visitChildren
    }
}

func calledName(_ call: FunctionCallExprSyntax) -> String? {
    if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text
    }
    if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
        return member.declName.baseName.text
    }
    return nil
}

func memberBaseName(_ call: FunctionCallExprSyntax) -> String? {
    guard let member = call.calledExpression.as(MemberAccessExprSyntax.self) else { return nil }
    return member.base?.trimmedDescription
}

func hasAncestor(_ node: Syntax, matching predicate: (Syntax) -> Bool) -> Bool {
    var current = node.parent
    while let candidate = current {
        if predicate(candidate) { return true }
        current = candidate.parent
    }
    return false
}

func hasAccessibilityIdentifier(_ node: Syntax) -> Bool {
    hasAncestor(node) { ancestor in
        guard let call = ancestor.as(FunctionCallExprSyntax.self) else { return false }
        return calledName(call) == "accessibilityIdentifier"
    }
}

func containsFunctionCall(_ node: Syntax, named name: String) -> Bool {
    final class CallFinder: SyntaxAnyVisitor {
        let name: String
        var found = false

        init(name: String) {
            self.name = name
            super.init(viewMode: .sourceAccurate)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let call = node.as(FunctionCallExprSyntax.self), calledName(call) == name {
                found = true
                return .skipChildren
            }
            return .visitChildren
        }
    }

    let finder = CallFinder(name: name)
    finder.walk(node)
    return finder.found
}

func hasStringInterpolation(_ literal: StringLiteralExprSyntax) -> Bool {
    literal.segments.contains { $0.as(ExpressionSegmentSyntax.self) != nil }
}

func literalValue(_ literal: StringLiteralExprSyntax) -> String {
    literal.segments.compactMap { segment in
        segment.as(StringSegmentSyntax.self)?.content.text
    }.joined()
}

func literalSourceValue(_ literal: StringLiteralExprSyntax) -> String {
    let text = literal.trimmedDescription
    guard text.count >= 2 else { return text }
    return String(text.dropFirst().dropLast())
}

func containsIdentifier(_ node: Syntax, named name: String) -> Bool {
    final class IdentifierFinder: SyntaxAnyVisitor {
        let name: String
        var found = false

        init(name: String) {
            self.name = name
            super.init(viewMode: .sourceAccurate)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            if let reference = node.as(DeclReferenceExprSyntax.self), reference.baseName.text == name {
                found = true
                return .skipChildren
            }
            if let member = node.as(MemberAccessExprSyntax.self), member.declName.baseName.text == name {
                found = true
                return .skipChildren
            }
            return .visitChildren
        }
    }

    let finder = IdentifierFinder(name: name)
    finder.walk(node)
    return finder.found
}

func containsVariableDeclaration(_ node: Syntax, named name: String) -> Bool {
    final class VariableFinder: SyntaxAnyVisitor {
        let name: String
        var found = false

        init(name: String) {
            self.name = name
            super.init(viewMode: .sourceAccurate)
        }

        override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
            guard let declaration = node.as(VariableDeclSyntax.self) else { return .visitChildren }
            if declaration.bindings.contains(where: { $0.pattern.trimmedDescription == name }) {
                found = true
                return .skipChildren
            }
            return .visitChildren
        }
    }

    let finder = VariableFinder(name: name)
    finder.walk(node)
    return finder.found
}

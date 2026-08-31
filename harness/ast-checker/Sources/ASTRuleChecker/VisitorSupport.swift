import SwiftSyntax

class RuleVisitor: SyntaxAnyVisitor {
    let source: ParsedSource
    var diagnostics: [Diagnostic] = []

    init(source: ParsedSource) {
        self.source = source
        super.init(viewMode: .sourceAccurate)
    }

    func report(rule: String, node: some SyntaxProtocol, message: String) {
        diagnostics.append(source.diagnostic(rule: rule, node: node, message: message))
    }

    func finish() -> [Diagnostic] {
        diagnostics.sorted {
            ($0.line, $0.column, $0.rule, $0.message) < ($1.line, $1.column, $1.rule, $1.message)
        }
    }
}

func sourceIsIn(_ source: ParsedSource, directory: String) -> Bool {
    source.path.contains("/\(directory)/")
}

func inheritedNames(_ declaration: some DeclSyntaxProtocol) -> [String] {
    if let node = declaration.as(StructDeclSyntax.self) {
        return node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
    }
    if let node = declaration.as(ClassDeclSyntax.self) {
        return node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
    }
    if let node = declaration.as(EnumDeclSyntax.self) {
        return node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
    }
    if let node = declaration.as(ProtocolDeclSyntax.self) {
        return node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
    }
    return []
}

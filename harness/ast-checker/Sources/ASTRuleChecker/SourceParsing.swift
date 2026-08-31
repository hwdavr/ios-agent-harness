import Foundation
import SwiftParser
import SwiftSyntax

public enum SourceParser {
    public static func parse(path: String) throws -> ParsedSource {
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw SourceParseError.unreadableFile(path: path, reason: error.localizedDescription)
        }

        let tree = Parser.parse(source: text)
        guard !tree.hasError else {
            throw SourceParseError.syntaxError(path: path)
        }
        return ParsedSource(path: path, text: text, tree: tree)
    }
}

public enum SyntaxText {
    public static func identifier(_ node: some SyntaxProtocol) -> String {
        node.trimmedDescription
            .split(separator: ".")
            .last
            .map(String.init) ?? node.trimmedDescription
    }

    public static func names(_ node: some SyntaxProtocol) -> [String] {
        node.trimmedDescription
            .split(separator: ".")
            .map(String.init)
    }

    public static func isTypeNamed(_ node: TypeSyntax, _ name: String) -> Bool {
        node.trimmedDescription == name || node.trimmedDescription.hasSuffix(".\(name)")
    }
}

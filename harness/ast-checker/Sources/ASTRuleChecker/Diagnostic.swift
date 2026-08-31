import Foundation
import SwiftSyntax

public enum RuleMode: String, CaseIterable {
    case architecture
    case swiftui
    case localization
    case navigation
}

public struct Diagnostic: Equatable, CustomStringConvertible {
    public let rule: String
    public let path: String
    public let line: Int
    public let column: Int
    public let message: String

    public init(rule: String, path: String, line: Int, column: Int, message: String) {
        self.rule = rule
        self.path = path
        self.line = line
        self.column = column
        self.message = message
    }

    public var description: String {
        "\(path):\(line):\(column): [\(rule)] \(message)"
    }
}

public struct ParsedSource {
    public let path: String
    public let text: String
    public let tree: SourceFileSyntax
    private let lineStarts: [Int]

    public init(path: String, text: String, tree: SourceFileSyntax) {
        self.path = path
        self.text = text
        self.tree = tree
        var starts = [0]
        for (offset, byte) in text.utf8.enumerated() where byte == 10 {
            starts.append(offset + 1)
        }
        lineStarts = starts
    }

    public func diagnostic(
        rule: String,
        node: some SyntaxProtocol,
        message: String
    ) -> Diagnostic {
        let offset = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let lineIndex = lineStarts.partitioningIndex { $0 > offset }
        let lineStart = lineStarts[max(0, lineIndex - 1)]
        return Diagnostic(
            rule: rule,
            path: path,
            line: lineIndex,
            column: max(1, offset - lineStart + 1),
            message: message
        )
    }
}

private extension Array where Element == Int {
    func partitioningIndex(where predicate: (Int) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            if predicate(self[middle]) {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return low
    }
}

public enum SourceParseError: Error, Equatable, CustomStringConvertible {
    case unreadableFile(path: String, reason: String)
    case syntaxError(path: String)

    public var description: String {
        switch self {
        case let .unreadableFile(path, reason):
            return "\(path): unable to read Swift source: \(reason)"
        case let .syntaxError(path):
            return "\(path): Swift parser reported a syntax error"
        }
    }
}

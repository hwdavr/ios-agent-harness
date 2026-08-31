import Foundation
import XCTest
@testable import ASTRuleChecker

final class ParserTests: XCTestCase {
    func testParserBuildsSyntaxTreeForMultilineSource() throws {
        let path = temporarySourcePath("valid")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try """
        struct Example {
            let value: String
        }
        """.write(toFile: path, atomically: true, encoding: .utf8)

        let source = try SourceParser.parse(path: path)

        XCTAssertFalse(source.tree.hasError)
        XCTAssertEqual(source.tree.statements.count, 1)
    }

    func testParserFailsOnUnrecoverableSyntax() throws {
        let path = temporarySourcePath("invalid")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "func broken(".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SourceParser.parse(path: path)) { error in
            XCTAssertEqual(error as? SourceParseError, .syntaxError(path: path))
        }
    }

    func testCommandParserPreservesModeAndScopeOptions() throws {
        let configuration = try CheckerCommand.parse(arguments: [
            "navigation",
            "--project-root", "/tmp/project",
            "--source-root", "/tmp/project/NotesTakingAppiOS",
            "--all"
        ])

        XCTAssertEqual(configuration.mode, .navigation)
        XCTAssertEqual(configuration.projectRoot, "/tmp/project")
        XCTAssertEqual(configuration.sourceRoot, "/tmp/project/NotesTakingAppiOS")
        XCTAssertTrue(configuration.scanAll)
    }

    func testCommandParserDerivesSourceRootWhenOnlyProjectRootIsProvided() throws {
        let configuration = try CheckerCommand.parse(arguments: [
            "architecture",
            "--project-root", "/tmp/project"
        ])

        XCTAssertEqual(configuration.sourceRoot, "/tmp/project/NotesTakingAppiOS")
    }

    private func temporarySourcePath(_ suffix: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ast-rule-checker-\(suffix)-\(UUID().uuidString).swift")
            .path
    }
}

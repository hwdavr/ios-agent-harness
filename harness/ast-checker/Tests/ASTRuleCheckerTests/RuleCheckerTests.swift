import Foundation
import XCTest
@testable import ASTRuleChecker

final class RuleCheckerTests: XCTestCase {
    func testArchitectureMatchesImportsInsteadOfCommentText() throws {
        let source = try parse(
            path: "/tmp/ast-checker-fixture/Views/CommentOnly.swift",
            text: """
            struct CommentOnly: View {
                var body: some View { Text("import Data") }
            }
            // import SwiftUI
            """
        )

        let diagnostics = ASTRuleChecker().check(
            .architecture,
            source: source,
            context: context(for: source)
        )

        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testSwiftUIFindsMultilineHardcodedColorAndInteractiveElement() throws {
        let source = try parse(
            path: "/tmp/ast-checker-fixture/Views/InvalidView.swift",
            text: """
            struct InvalidView: View {
                var body: some View {
                    VStack { ForEach(items) { item in Button("Tap") {} } }
                    Color.red
                }
            }
            """
        )

        let diagnostics = ASTRuleChecker().check(
            .swiftui,
            source: source,
            context: context(for: source, registry: DynamicIdentifierRegistry(entries: [
                .init(
                    id: "fixture",
                    file: "Views/InvalidView.swift",
                    documentation: "docs/fixture.md",
                    template: "fixture",
                    sourceType: "immutable-screen-prefix",
                    linePattern: "^$"
                )
            ]))
        )

        XCTAssertTrue(diagnostics.contains { $0.message == "Hardcoded Color literal" })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("Interactive element 'Button'") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("VStack with ForEach") })
        XCTAssertTrue(diagnostics.contains { $0.message == "Hardcoded string in Text()" })
    }

    func testLocalizationChecksCatalogKeysFromSyntaxNodes() throws {
        let source = try parse(
            path: "/tmp/ast-checker-fixture/Views/InvalidLocalization.swift",
            text: """
            struct InvalidLocalization: View {
                var body: some View { Text("Hello") }
            }
            """
        )

        let diagnostics = ASTRuleChecker().check(
            .localization,
            source: source,
            context: context(for: source, catalog: StringCatalog(keys: ["notes_title_copy"]))
        )

        XCTAssertTrue(diagnostics.contains { $0.message.contains("prefixed localization key") })
    }

    func testLocalizationChecksDomainErrorMessages() throws {
        let source = try parse(
            path: "/tmp/ast-checker-fixture/Domain/Errors.swift",
            text: """
            enum Errors {
                static func invalidMessage() -> String {
                    return .invalid(message: "Unsupported Mermaid diagram type")
                }

                static func shareMessage() -> String {
                    return .shareFailed("Invite failed")
                }
            }
            """
        )

        let diagnostics = ASTRuleChecker().check(
            .localization,
            source: source,
            context: context(for: source)
        )

        XCTAssertGreaterThanOrEqual(
            diagnostics.filter { $0.message == "app-owned error message must come from a localization resource" }.count,
            2
        )
    }

    func testNavigationRouteArgumentsAreCheckedStructurally() throws {
        let source = try parse(
            path: "/tmp/ast-checker-fixture/ViewModels/Routes.swift",
            text: """
            enum NoteDestination: Equatable {
                case editor(note: NoteModel)
            }
            struct NoteModel {}
            """
        )

        let diagnostics = ASTRuleChecker().check(
            .navigation,
            source: source,
            context: context(for: source)
        )

        XCTAssertTrue(diagnostics.contains { $0.message.contains("must conform to Hashable") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("non-Hashable or complex type") })
    }

    private func parse(path: String, text: String) throws -> ParsedSource {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return try SourceParser.parse(path: path)
    }

    private func context(
        for source: ParsedSource,
        registry: DynamicIdentifierRegistry? = nil,
        catalog: StringCatalog? = nil
    ) -> CheckerContext {
        CheckerContext(
            projectRoot: "/tmp/ast-checker-fixture",
            sourceRoot: "/tmp/ast-checker-fixture",
            registry: registry,
            catalog: catalog
        )
    }
}

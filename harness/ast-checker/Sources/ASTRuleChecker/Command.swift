import Foundation
import SwiftSyntax

public struct CheckerConfiguration: Equatable {
    public let mode: RuleMode
    public let projectRoot: String
    public let sourceRoot: String
    public let scanAll: Bool
    public let registryPath: String?
    public let catalogPath: String?

    public init(
        mode: RuleMode,
        projectRoot: String,
        sourceRoot: String,
        scanAll: Bool,
        registryPath: String? = nil,
        catalogPath: String? = nil
    ) {
        self.mode = mode
        self.projectRoot = projectRoot
        self.sourceRoot = sourceRoot
        self.scanAll = scanAll
        self.registryPath = registryPath
        self.catalogPath = catalogPath
    }
}

public enum CheckerCommandError: Error, Equatable, CustomStringConvertible {
    case missingMode
    case unknownMode(String)
    case missingValue(String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case .missingMode: return "missing checker mode (architecture, swiftui, localization, or navigation)"
        case let .unknownMode(mode): return "unknown checker mode: \(mode)"
        case let .missingValue(option): return "missing value for \(option)"
        case let .unknownOption(option): return "unknown option: \(option)"
        }
    }
}

public enum CheckerCommand {
    public static func parse(arguments: [String]) throws -> CheckerConfiguration {
        guard let rawMode = arguments.first else { throw CheckerCommandError.missingMode }
        guard let mode = RuleMode(rawValue: rawMode) else { throw CheckerCommandError.unknownMode(rawMode) }

        let options = try parseOptions(Array(arguments.dropFirst()))
        let sourceRoot = options.sourceRoot ?? URL(fileURLWithPath: options.projectRoot)
            .appendingPathComponent("NotesTakingAppiOS").path
        return CheckerConfiguration(
            mode: mode,
            projectRoot: options.projectRoot,
            sourceRoot: sourceRoot,
            scanAll: options.scanAll,
            registryPath: options.registryPath,
            catalogPath: options.catalogPath
        )
    }

    private struct Options {
        var projectRoot = FileManager.default.currentDirectoryPath
        var sourceRoot: String?
        var scanAll = false
        var registryPath: String?
        var catalogPath: String?
    }

    private static func parseOptions(_ arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--all":
                options.scanAll = true
            case "--project-root", "--source-root", "--registry", "--catalog":
                guard index + 1 < arguments.count else { throw CheckerCommandError.missingValue(option) }
                let value = arguments[index + 1]
                switch option {
                case "--project-root": options.projectRoot = value
                case "--source-root":
                    options.sourceRoot = value
                case "--registry": options.registryPath = value
                default: options.catalogPath = value
                }
                index += 1
            default:
                throw CheckerCommandError.unknownOption(option)
            }
            index += 1
        }
        return options
    }
}

public struct CheckerRunner {
    public init() {}

    public func run(configuration: CheckerConfiguration, output: (String) -> Void = { print($0) }) -> Int32 {
        guard FileManager.default.fileExists(atPath: configuration.sourceRoot) else {
            output("FAIL: source root does not exist: \(configuration.sourceRoot)")
            return 1
        }

        do {
            let inputs = try loadInputs(configuration)
            return evaluate(configuration: configuration, inputs: inputs, output: output)
        } catch let error as JSONValidationError {
            output("    \(error.description)")
            return 1
        } catch {
            output("    \(error.localizedDescription)")
            return 1
        }
    }

    private struct Inputs {
        let registry: DynamicIdentifierRegistry?
        let catalog: StringCatalog?
        let parsed: [ParsedSource]
        let diagnostics: [Diagnostic]
    }

    private func loadInputs(_ configuration: CheckerConfiguration) throws -> Inputs {
        let registry = try loadRegistry(configuration)
        let catalog = try loadCatalog(configuration)
        let selection = SourceDiscovery.select(
            sourceRoot: configuration.sourceRoot,
            projectRoot: configuration.projectRoot,
            all: configuration.scanAll || configuration.mode == .localization || configuration.mode == .navigation
        )
        let parsed = parseSources(selection.files)
        var diagnostics = catalogDiagnostics(catalog, configuration: configuration)
        diagnostics += parsed.diagnostics
        diagnostics += navigationDiagnostics(configuration)
        return Inputs(registry: registry, catalog: catalog, parsed: parsed.sources, diagnostics: diagnostics)
    }

    private func parseSources(_ paths: [String]) -> (sources: [ParsedSource], diagnostics: [Diagnostic]) {
        var sources: [ParsedSource] = []
        var diagnostics: [Diagnostic] = []
        for path in paths {
            do {
                sources.append(try SourceParser.parse(path: path))
            } catch let error as SourceParseError {
                diagnostics.append(
                    Diagnostic(rule: "PARSE", path: path, line: 1, column: 1, message: error.description)
                )
            } catch {
                diagnostics.append(
                    Diagnostic(rule: "PARSE", path: path, line: 1, column: 1, message: error.localizedDescription)
                )
            }
        }
        return (sources, diagnostics)
    }

    private func catalogDiagnostics(
        _ catalog: StringCatalog?,
        configuration: CheckerConfiguration
    ) -> [Diagnostic] {
        guard configuration.mode == .localization, let catalog else { return [] }
        let path = configuration.catalogPath ?? URL(fileURLWithPath: configuration.sourceRoot)
            .appendingPathComponent("Localizable.xcstrings").path
        return catalog.invalidKeys.map {
            Diagnostic(
                rule: "L10N",
                path: path,
                line: 1,
                column: 1,
                message: "catalog key must follow <screen>_<component>_<type>: \"\($0)\""
            )
        }
    }

    private func navigationDiagnostics(_ configuration: CheckerConfiguration) -> [Diagnostic] {
        guard configuration.mode == .navigation else { return [] }
        let mainPath = URL(fileURLWithPath: configuration.sourceRoot)
            .appendingPathComponent("Views/Main/MainTabView.swift").path
        guard !FileManager.default.fileExists(atPath: mainPath) else { return [] }
        return [Diagnostic(
            rule: "NAV",
            path: mainPath,
            line: 1,
            column: 1,
            message: "MainTabView.swift is required for the root navigation contract"
        )]
    }

    private func evaluate(
        configuration: CheckerConfiguration,
        inputs: Inputs,
        output: (String) -> Void
    ) -> Int32 {
        let context = CheckerContext(
            projectRoot: URL(fileURLWithPath: configuration.projectRoot).standardizedFileURL.path,
            sourceRoot: URL(fileURLWithPath: configuration.sourceRoot).standardizedFileURL.path,
            registry: inputs.registry,
            catalog: inputs.catalog,
            hashableTypes: hashableTypes(in: inputs.parsed),
            hasNavigationDefaultValue: inputs.parsed.contains {
                containsVariableDeclaration(Syntax($0.tree), named: "defaultValue")
            }
        )
        var diagnostics = inputs.diagnostics
        let checker = ASTRuleChecker()
        for source in inputs.parsed {
            diagnostics += checker.check(configuration.mode, source: source, context: context)
        }
        return emit(diagnostics, mode: configuration.mode, output: output)
    }

    private func emit(
        _ diagnostics: [Diagnostic],
        mode: RuleMode,
        output: (String) -> Void
    ) -> Int32 {
        let sortedDiagnostics = diagnostics.sorted {
            ($0.path, $0.line, $0.column, $0.rule) < ($1.path, $1.line, $1.column, $1.rule)
        }
        for diagnostic in sortedDiagnostics {
            output("    \(diagnostic.description)")
        }
        guard diagnostics.isEmpty else {
            output("\(diagnostics.count) \(mode.rawValue) violation(s) found")
            return 1
        }
        output("All \(mode.rawValue) rules passed")
        return 0
    }

    private func loadRegistry(_ configuration: CheckerConfiguration) throws -> DynamicIdentifierRegistry? {
        guard configuration.mode == .swiftui else { return nil }
        let path = configuration.registryPath ?? URL(fileURLWithPath: configuration.projectRoot)
            .appendingPathComponent("harness/rules-matrix/documented-dynamic-accessibility-identifiers.json").path
        let registry = try DynamicIdentifierRegistry.load(path: path)
        let fileManager = FileManager.default
        for entry in registry.entries {
            let sourcePath = URL(fileURLWithPath: configuration.projectRoot)
                .appendingPathComponent(entry.file).path
            guard fileManager.fileExists(atPath: sourcePath) else {
                throw JSONValidationError(
                    path: path,
                    message: "Registry entry \(entry.id) references missing source file: \(entry.file)"
                )
            }
            guard !entry.documentation.hasPrefix("/"), !entry.documentation.contains("..") else {
                throw JSONValidationError(
                    path: path,
                    message: "Registry entry \(entry.id) has an unsafe documentation path: \(entry.documentation)"
                )
            }
            let documentationPath = URL(fileURLWithPath: configuration.projectRoot)
                .appendingPathComponent(entry.documentation).path
            guard fileManager.fileExists(atPath: documentationPath) else {
                throw JSONValidationError(
                    path: path,
                    message: "Registry entry \(entry.id) references missing documentation: \(entry.documentation)"
                )
            }
            let documentation = try String(contentsOfFile: documentationPath, encoding: .utf8)
            guard documentation.contains(entry.template) else {
                throw JSONValidationError(
                    path: path,
                    message: "Registry entry \(entry.id) is not documented by template " +
                        "'\(entry.template)' in \(entry.documentation)"
                )
            }
        }
        return registry
    }

    private func loadCatalog(_ configuration: CheckerConfiguration) throws -> StringCatalog? {
        guard configuration.mode == .localization else { return nil }
        let path = configuration.catalogPath ?? URL(fileURLWithPath: configuration.sourceRoot)
            .appendingPathComponent("Localizable.xcstrings").path
        return try StringCatalog.load(path: path)
    }

    private func hashableTypes(in sources: [ParsedSource]) -> Set<String> {
        var names = Set<String>()
        for source in sources {
            final class Visitor: SyntaxAnyVisitor {
                var names = Set<String>()

                init() {
                    super.init(viewMode: .sourceAccurate)
                }

                override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
                    if let declaration = node.as(EnumDeclSyntax.self),
                       inheritedNames(declaration).contains("Hashable") {
                        names.insert(declaration.name.text)
                    }
                    if let declaration = node.as(StructDeclSyntax.self),
                       inheritedNames(declaration).contains("Hashable") {
                        names.insert(declaration.name.text)
                    }
                    if let declaration = node.as(ClassDeclSyntax.self),
                       inheritedNames(declaration).contains("Hashable") {
                        names.insert(declaration.name.text)
                    }
                    return .visitChildren
                }
            }
            let visitor = Visitor()
            visitor.walk(source.tree)
            names.formUnion(visitor.names)
        }
        return names
    }
}

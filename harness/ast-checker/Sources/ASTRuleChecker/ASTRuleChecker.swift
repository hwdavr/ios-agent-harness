import Foundation
import SwiftSyntax

public struct ASTRuleChecker {
    public init() {}

    public func check(_ mode: RuleMode, source: ParsedSource, context: CheckerContext) -> [Diagnostic] {
        switch mode {
        case .architecture:
            return ArchitectureRuleChecker(context: context).check(source)
        case .swiftui:
            return SwiftUIRuleChecker(context: context).check(source)
        case .localization:
            return LocalizationRuleChecker(context: context).check(source)
        case .navigation:
            return NavigationRuleChecker(context: context).check(source)
        }
    }
}

public struct CheckerContext {
    public let projectRoot: String
    public let sourceRoot: String
    public let registry: DynamicIdentifierRegistry?
    public let catalog: StringCatalog?
    public let hashableTypes: Set<String>
    public let hasNavigationDefaultValue: Bool

    public init(
        projectRoot: String,
        sourceRoot: String,
        registry: DynamicIdentifierRegistry? = nil,
        catalog: StringCatalog? = nil,
        hashableTypes: Set<String> = [],
        hasNavigationDefaultValue: Bool = false
    ) {
        self.projectRoot = projectRoot
        self.sourceRoot = sourceRoot
        self.registry = registry
        self.catalog = catalog
        self.hashableTypes = hashableTypes
        self.hasNavigationDefaultValue = hasNavigationDefaultValue
    }
}

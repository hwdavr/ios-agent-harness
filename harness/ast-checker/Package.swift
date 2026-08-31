// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ASTRuleChecker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ast-rule-checker",
            targets: ["ASTRuleCheckerCLI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "600.0.1"
        )
    ],
    targets: [
        .target(
            name: "ASTRuleChecker",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "ASTRuleCheckerCLI",
            dependencies: ["ASTRuleChecker"]
        ),
        .testTarget(
            name: "ASTRuleCheckerTests",
            dependencies: ["ASTRuleChecker"],
            path: "Tests/ASTRuleCheckerTests"
        )
    ]
)

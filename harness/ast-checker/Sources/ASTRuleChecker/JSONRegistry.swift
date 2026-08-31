import Foundation

public struct DynamicIdentifierRegistry: Codable {
    public struct Entry: Codable {
        public let id: String
        public let file: String
        public let documentation: String
        public let template: String
        public let sourceType: String
        public let linePattern: String

        public init(
            id: String,
            file: String,
            documentation: String,
            template: String,
            sourceType: String,
            linePattern: String
        ) {
            self.id = id
            self.file = file
            self.documentation = documentation
            self.template = template
            self.sourceType = sourceType
            self.linePattern = linePattern
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public func matches(relativeFile: String, sourceLine: String) -> Bool {
        entries.contains { entry in
            guard entry.file == relativeFile else { return false }
            guard let expression = try? NSRegularExpression(pattern: entry.linePattern) else { return false }
            let range = NSRange(sourceLine.startIndex..<sourceLine.endIndex, in: sourceLine)
            return expression.firstMatch(in: sourceLine, range: range) != nil
        }
    }

    public static func load(path: String) throws -> DynamicIdentifierRegistry {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw JSONValidationError(
                path: path,
                message: "Missing documented dynamic accessibility-identifier registry"
            )
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let registry: DynamicIdentifierRegistry
        do {
            registry = try decoder.decode(DynamicIdentifierRegistry.self, from: data)
        } catch {
            throw JSONValidationError(path: path, message: "Invalid dynamic accessibility-identifier registry")
        }
        guard !registry.entries.isEmpty,
              registry.entries.allSatisfy({
                  !$0.id.isEmpty && !$0.file.isEmpty && !$0.documentation.isEmpty &&
                      !$0.template.isEmpty &&
                      ["immutable-domain-id", "fixed-catalog-key", "immutable-screen-prefix"].contains($0.sourceType) &&
                      !$0.linePattern.isEmpty
              }) else {
            throw JSONValidationError(path: path, message: "Invalid dynamic accessibility-identifier registry")
        }
        return registry
    }
}

public struct StringCatalog {
    private let keys: Set<String>
    public let invalidKeys: [String]

    public init(keys: Set<String>, invalidKeys: [String] = []) {
        self.keys = keys
        self.invalidKeys = invalidKeys
    }

    public func hasKey(_ key: String) -> Bool {
        let base = key.split(separator: " ", maxSplits: 1).first.map(String.init) ?? key
        return keys.contains(base) || keys.contains(where: { $0.hasPrefix(base + " ") })
    }

    public static func load(path: String) throws -> StringCatalog {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw JSONValidationError(path: path, message: "required String Catalog is missing")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw JSONValidationError(path: path, message: "String Catalog is not valid JSON")
        }

        guard let dictionary = object as? [String: Any],
              let sourceLanguage = dictionary["sourceLanguage"] as? String,
              !sourceLanguage.isEmpty,
              dictionary["version"] != nil,
              let strings = dictionary["strings"] as? [String: Any] else {
            throw JSONValidationError(
                path: path,
                message: "String Catalog must contain sourceLanguage, strings, and version"
            )
        }

        let keys = Set(strings.keys)
        let invalidKeys = keys
            .filter { !$0.isEmpty && !$0.hasPrefix("%") && !isValidLocalizationKey($0) }
            .sorted()
        return StringCatalog(keys: keys, invalidKeys: invalidKeys)
    }
}

public struct JSONValidationError: Error, Equatable, CustomStringConvertible {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String { "\(path): \(message)" }
}

func isValidLocalizationKey(_ key: String) -> Bool {
    let base = key.split(separator: " ", maxSplits: 1).first.map(String.init) ?? key
    guard let expression = try? NSRegularExpression(
        pattern: "^[a-z][a-z0-9]*(?:_[a-z0-9]+){2,}$"
    ) else { return false }
    let range = NSRange(base.startIndex..<base.endIndex, in: base)
    return expression.firstMatch(in: base, range: range) != nil
}

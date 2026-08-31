import Foundation

public struct SourceSelection {
    public let files: [String]
    public let usedFullScan: Bool

    public init(files: [String], usedFullScan: Bool) {
        self.files = files
        self.usedFullScan = usedFullScan
    }
}

public enum SourceDiscovery {
    public static func select(
        sourceRoot: String,
        projectRoot: String,
        all: Bool
    ) -> SourceSelection {
        let full = all || !isGitRepository(at: projectRoot)
        if full { return SourceSelection(files: allSwiftFiles(in: sourceRoot), usedFullScan: true) }

        let changed = changedSwiftFiles(projectRoot: projectRoot, sourceRoot: sourceRoot)
        return changed.isEmpty
            ? SourceSelection(files: allSwiftFiles(in: sourceRoot), usedFullScan: true)
            : SourceSelection(files: changed, usedFullScan: false)
    }

    private static func allSwiftFiles(in root: String) -> [String] {
        guard let paths = try? FileManager.default.subpathsOfDirectory(atPath: root) else { return [] }
        return paths
            .filter { $0.hasSuffix(".swift") }
            .map { URL(fileURLWithPath: root).appendingPathComponent($0).path }
            .sorted()
    }

    private static func changedSwiftFiles(projectRoot: String, sourceRoot: String) -> [String] {
        let sourcePrefix = URL(fileURLWithPath: sourceRoot).standardizedFileURL.path + "/"
        var paths = Set<String>()
        for arguments in [
            ["diff", "--name-only", "--diff-filter=d", "HEAD"],
            ["diff", "--name-only", "--cached", "--diff-filter=d"],
            ["ls-files", "--others", "--exclude-standard"]
        ] {
            guard let output = runGit(projectRoot: projectRoot, arguments: arguments) else { continue }
            for relative in output.split(whereSeparator: \.isNewline).map(String.init)
                where relative.hasSuffix(".swift") {
                let absolute = URL(fileURLWithPath: projectRoot)
                    .appendingPathComponent(relative).standardizedFileURL.path
                if absolute.hasPrefix(sourcePrefix) { paths.insert(absolute) }
            }
        }
        return paths.sorted()
    }

    private static func isGitRepository(at root: String) -> Bool {
        runGit(projectRoot: root, arguments: ["rev-parse", "--is-inside-work-tree"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private static func runGit(projectRoot: String, arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", projectRoot] + arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

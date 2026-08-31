import Darwin
import Foundation
import ASTRuleChecker

@main
struct ASTRuleCheckerMain {
    static func main() {
        do {
            let configuration = try CheckerCommand.parse(arguments: Array(CommandLine.arguments.dropFirst()))
            let status = CheckerRunner().run(configuration: configuration)
            exit(status)
        } catch let error as CheckerCommandError {
            print("FAIL: \(error.description)")
            exit(1)
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}

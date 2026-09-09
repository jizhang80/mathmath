import Core
import Foundation

/// `core-cli validate <bundle-dir>`. Prints the L0 report as JSON on stdout
/// (`contracts/graph-constraints.md` § Report shape) and exits per the task spec's exit-code table.
enum ValidateCommand {
    static func run(arguments: [String]) {
        guard arguments.count == 1 else { Usage.printAndExit() }
        let bundleDir = URL(fileURLWithPath: arguments[0], isDirectory: true)

        let report: L0Report
        do {
            report = try L0Checker.validate(bundleDir: bundleDir)
        } catch let error as CoreError {
            Usage.fail(error)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(3)
        }

        let data: Data
        do {
            data = try CoreCoding.encoder.encode(report)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(3)
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(report.passed ? 0 : 1)
    }
}

import Core
import Foundation

// core-cli — the single entry point through which the Python pipeline invokes `Core` (D42):
// L0 validation and layout precompute.

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "version":
    print(CoreInfo.dataFormatVersion)
case "validate":
    ValidateCommand.run(arguments: Array(arguments.dropFirst()))
case "layout":
    LayoutCommand.run(arguments: Array(arguments.dropFirst()))
default:
    Usage.printAndExit()
}

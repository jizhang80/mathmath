import Core
import Foundation

// core-cli — the single entry point through which the Python pipeline invokes `Core` (D42):
// L0 validation and layout precompute. Subcommands are added by the EPICs that ship them.
// Phase 5 placeholder: reports the data-format version so the pipeline↔Core seam is exercisable.

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "version":
    print(CoreInfo.dataFormatVersion)
default:
    FileHandle.standardError.write(Data("usage: core-cli version\n".utf8))
    exit(2)
}

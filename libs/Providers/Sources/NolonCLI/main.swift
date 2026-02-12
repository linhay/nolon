import Foundation
import NolonCoreCLIKit

@main
struct NolonCLIApp {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let result = await NolonCLIEntrypoint.execute(arguments: args)

        if !result.stdout.isEmpty {
            FileHandle.standardOutput.write(Data((result.stdout + "\n").utf8))
        }
        if !result.stderr.isEmpty {
            FileHandle.standardError.write(Data((result.stderr + "\n").utf8))
        }
        exit(result.exitCode)
    }
}

import Foundation
import NolonCoreCLIKit

@main
struct NolonCoreCLIApp {
    static func main() async {
        let runner = NolonCoreCLIRunner()
        let args = Array(CommandLine.arguments.dropFirst())
        let result = await runner.execute(arguments: args)

        if !result.stdout.isEmpty {
            FileHandle.standardOutput.write(Data((result.stdout + "\n").utf8))
        }
        if !result.stderr.isEmpty {
            FileHandle.standardError.write(Data((result.stderr + "\n").utf8))
        }
        exit(result.exitCode)
    }
}

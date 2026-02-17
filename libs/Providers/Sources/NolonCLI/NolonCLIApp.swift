import Foundation
import NolonCoreCLIKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct NolonCLIApp {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let signalState = InterruptState()
        let executionTask = Task {
            await NolonCLIEntrypoint.execute(arguments: args)
        }
        let signalHandlers = installSignalHandlers(
            state: signalState,
            task: executionTask
        )

        let result = await executionTask.value
        signalHandlers.cancel()

        if signalState.wasInterrupted {
            exit(130)
        }

        if !result.stdout.isEmpty {
            FileHandle.standardOutput.write(Data((result.stdout + "\n").utf8))
        }
        if !result.stderr.isEmpty {
            FileHandle.standardError.write(Data((result.stderr + "\n").utf8))
        }
        exit(result.exitCode)
    }

    private static func installSignalHandlers(
        state: InterruptState,
        task: Task<NolonCLIExecutionResult, Never>
    ) -> SignalHandlers {
        #if canImport(Darwin) || canImport(Glibc)
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let queue = DispatchQueue(label: "nolon.cli.signal")
        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)

        let handler = {
            if state.markInterrupted() == 1 {
                task.cancel()
            } else {
                _exit(130)
            }
        }
        intSource.setEventHandler(handler: handler)
        termSource.setEventHandler(handler: handler)
        intSource.resume()
        termSource.resume()
        return SignalHandlers(intSource: intSource, termSource: termSource)
        #else
        return SignalHandlers(intSource: nil, termSource: nil)
        #endif
    }
}

private final class InterruptState: @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int = 0

    @discardableResult
    func markInterrupted() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var wasInterrupted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count > 0
    }
}

private struct SignalHandlers {
    let intSource: DispatchSourceSignal?
    let termSource: DispatchSourceSignal?

    func cancel() {
        intSource?.cancel()
        termSource?.cancel()
    }
}

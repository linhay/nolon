import Foundation
import Testing
import STFilePath

@Suite("Process Runner Convergence")
struct ProcessRunnerConvergenceTests {
    @Test("Production sources should not use Process directly except JsonRPC pipe session")
    func productionSourcesAvoidDirectProcess() throws {
        let sourcesRoot = try providersSourcesRoot()
        let allowed = Set([
            "Providers/Sources/JsonRPCKit/JsonRPCLineProcessSession.swift",
        ])

        let files = try swiftFiles(in: sourcesRoot)
        var offenders: [String] = []
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            guard containsDirectProcessUsage(content) else { continue }
            let relative = relativePath(from: sourcesRoot.deletingLastPathComponent().deletingLastPathComponent(), to: file)
            if !allowed.contains(relative) {
                offenders.append(relative)
            }
        }

        #expect(offenders.isEmpty, "Unexpected direct Process usage in: \(offenders.joined(separator: ", "))")
    }

    private func providersSourcesRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        // .../libs/Providers/Tests/ProvidersTests/<file>.swift -> libs/Providers/Sources
        let root = here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        guard STPath(sources.path).isExists else {
            throw NSError(domain: "ProcessRunnerConvergenceTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Sources root not found: \(sources.path)",
            ])
        }
        return sources
    }

    private func swiftFiles(in root: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            guard next.pathExtension == "swift" else { continue }
            files.append(next)
        }
        return files
    }

    private func containsDirectProcessUsage(_ content: String) -> Bool {
        let patterns = [
            #"\bProcess\s*\("#,
            #":\s*Process\b"#,
            #"=\s*Process\s*\("#,
        ]
        return patterns.contains { pattern in
            content.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private func relativePath(from root: URL, to file: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return filePath }
        return String(filePath.dropFirst(rootPath.count + 1))
    }
}

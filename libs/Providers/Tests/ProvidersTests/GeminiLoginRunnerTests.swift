import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiLoginRunner")
struct GeminiLoginRunnerTests {
    @Test("resolve executable uses user shell resolver result when available")
    func resolveExecutableUsesUserShellResolver() throws {
        let expected = URL(fileURLWithPath: "/tmp/fake-gemini")
        let resolved = try GeminiLoginRunner.resolveExecutableURL(
            binary: "gemini",
            environment: ["PATH": "/usr/bin:/bin"],
            shellResolver: { binary, _ in
                #expect(binary == "gemini")
                return expected
            }
        )

        #expect(resolved.path == expected.path)
    }

    @Test("resolve executable throws not found when user shell resolver misses binary")
    func resolveExecutableThrowsWhenShellResolverMissesBinary() {
        #expect(throws: GeminiLoginError.binaryNotFound("gemini")) {
            _ = try GeminiLoginRunner.resolveExecutableURL(
                binary: "gemini",
                environment: ["PATH": "/usr/bin:/bin"],
                shellResolver: { _, _ in nil }
            )
        }
    }

    @Test("resolve executable accepts explicit executable path")
    func resolveExecutableAcceptsExplicitPath() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-login-runner-explicit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let executable = root.appendingPathComponent("gemini", isDirectory: false)
        let payload = try #require("#!/bin/sh\necho explicit\n".data(using: .utf8))
        try payload.write(to: executable, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let resolved = try GeminiLoginRunner.resolveExecutableURL(
            binary: executable.path,
            environment: [:]
        )

        #expect(resolved.path == executable.path)
    }
}

import Foundation
import Testing
@testable import ProvidersShared

@Suite("TTYCommandRunner")
struct TTYCommandRunnerTests {
    @Test("which accepts absolute executable path")
    func whichAbsoluteExecutable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tty-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let script = root.appendingPathComponent("tool", isDirectory: false)
        FileManager.default.createFile(atPath: script.path, contents: Data("#!/bin/sh\nexit 0\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        #expect(TTYCommandRunner.which(script.path) == script.path)
    }

    @Test("which rejects non executable absolute path")
    func whichRejectsNonExecutableAbsolutePath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tty-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("tool", isDirectory: false)
        FileManager.default.createFile(atPath: file.path, contents: Data("plain".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)

        #expect(TTYCommandRunner.which(file.path) == nil)
    }
}

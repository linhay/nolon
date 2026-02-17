import Foundation
import Testing
import STFilePath
@testable import ProvidersShared

@Suite("TTYCommandRunner")
struct TTYCommandRunnerTests {
    @Test("which accepts absolute executable path")
    func whichAbsoluteExecutable() throws {
        let root = STFolder("/tmp").folder("tty-runner-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let script = root.file("tool")
        try script.overlay(with: "#!/bin/sh\nexit 0\n")
        try script.set(permissions: .default)

        #expect(TTYCommandRunner.which(script.url.path) == script.url.path)
    }

    @Test("which rejects non executable absolute path")
    func whichRejectsNonExecutableAbsolutePath() throws {
        let root = STFolder("/tmp").folder("tty-runner-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let file = root.file("tool")
        try file.overlay(with: "plain")
        try file.set(permissions: [.ownerRead, .ownerWrite, .groupRead, .othersRead])

        #expect(TTYCommandRunner.which(file.url.path) == nil)
    }
}

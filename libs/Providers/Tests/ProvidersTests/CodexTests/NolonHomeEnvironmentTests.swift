import Foundation
import Testing
import STFilePath
@testable import ProvidersShared

@Suite("NolonHomeEnvironment")
struct NolonHomeEnvironmentTests {
    @Test("Given absolute NOLON_HOME env, when resolving, then returns absolute folder")
    func resolvesAbsoluteEnvironmentPath() {
        let folder = NolonHomeEnvironment.resolveNolonHomeFolder(
            environment: [NolonHomeEnvironment.variableName: "/tmp/nolon-home-abs"]
        )
        #expect(folder.url.standardizedFileURL.path == STFolder("/tmp/nolon-home-abs").url.standardizedFileURL.path)
    }

    @Test("Given relative NOLON_HOME env, when resolving, then returns current-directory relative folder")
    func resolvesRelativeEnvironmentPath() {
        let relative = "tmp/nolon-home-rel"
        let folder = NolonHomeEnvironment.resolveNolonHomeFolder(
            environment: [NolonHomeEnvironment.variableName: relative]
        )
        let expected = STFolder(FileManager.default.currentDirectoryPath).folder(relative)
        #expect(folder.url.standardizedFileURL.path == expected.url.standardizedFileURL.path)
    }

    @Test("Given missing NOLON_HOME env, when resolving, then falls back to user home .nolon")
    func fallbackToUserHome() {
        let userHome = STFolder("/tmp/nolon-user-home").url
        let folder = NolonHomeEnvironment.resolveNolonHomeFolder(
            environment: [:],
            userHomeURL: userHome
        )
        #expect(folder.url.standardizedFileURL.path == STFolder(userHome).folder(".nolon").url.standardizedFileURL.path)
    }
}

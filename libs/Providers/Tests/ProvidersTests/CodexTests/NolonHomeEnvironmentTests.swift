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

    @Test("Given xctest env without NOLON_HOME, when resolving, then uses isolated temporary home")
    func fallbackToTemporaryHomeUnderXCTest() {
        let userHome = STFolder(NSHomeDirectory()).url
        let environment = ["XCTestConfigurationFilePath": "/tmp/session-123.xctestconfiguration"]

        let folder = NolonHomeEnvironment.resolveNolonHomeFolder(
            environment: environment,
            userHomeURL: userHome
        )

        #expect(folder.url.path.contains("/nolon-xctest-"))
        #expect(folder.url.standardizedFileURL.path != STFolder(userHome).folder(".nolon").url.standardizedFileURL.path)
    }

    @Test("Given xctest env with custom home, when resolving, then keeps the injected home sandbox")
    func customHomeRemainsStableUnderXCTest() {
        let userHome = STFolder("/tmp/nolon-user-home").url
        let environment = ["XCTestConfigurationFilePath": "/tmp/session-123.xctestconfiguration"]

        let folder = NolonHomeEnvironment.resolveNolonHomeFolder(
            environment: environment,
            userHomeURL: userHome
        )

        #expect(folder.url.standardizedFileURL.path == STFolder(userHome).folder(".nolon").url.standardizedFileURL.path)
        #expect(folder.url.path.contains("/tmp/nolon-user-home/.nolon"))
    }

    @Test("Given xctest env without explicit app support root, when resolving, then uses isolated temporary app support")
    func fallbackToTemporaryApplicationSupportUnderXCTest() {
        let userHome = STFolder(NSHomeDirectory()).url
        let environment = ["XCTestSessionIdentifier": "session-123"]

        let folder = NolonHomeEnvironment.resolveApplicationSupportFolder(
            environment: environment,
            userHomeURL: userHome
        )

        #expect(folder.path.contains("/nolon-xctest-"))
        #expect(folder.path.hasSuffix("/Library/Application Support"))
        #expect(folder.standardizedFileURL.path != userHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .standardizedFileURL.path)
    }

    @Test("Given xctest env with custom home and app support lookup, when resolving, then keeps the injected app support sandbox")
    func customApplicationSupportRemainsStableUnderXCTest() {
        let userHome = STFolder("/tmp/nolon-user-home").url
        let environment = ["XCTestSessionIdentifier": "session-123"]

        let folder = NolonHomeEnvironment.resolveApplicationSupportFolder(
            environment: environment,
            userHomeURL: userHome
        )

        #expect(folder.standardizedFileURL.path == userHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .standardizedFileURL.path)
        #expect(folder.path.contains("/tmp/nolon-user-home/Library/Application Support"))
    }
}

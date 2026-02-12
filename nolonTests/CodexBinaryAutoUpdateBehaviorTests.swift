import XCTest
@testable import nolon
import STFilePath
import CodexProvider

final class CodexBinaryAutoUpdateBehaviorTests: XCTestCase {
    func testBDD_GivenLastUpdateCheckIsWithin24Hours_WhenCheckingForUpdates_ThenSkipsRemoteRequest() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)
        var manifest = CodexBinaryManifest.default
        manifest.lastUpdateCheckAt = Date()
        manifest.updateState = .idle
        _ = try await manager.saveManifest(manifest)

        // When
        let result = await manager.checkForRustReleaseUpdateIfNeeded(force: false)

        // Then
        XCTAssertEqual(result.updateState, .idle)
        XCTAssertNotNil(result.lastUpdateCheckAt)
    }

    func testBDD_GivenLastUpdateCheckIsOlderThan24Hours_WhenCheckingForUpdates_ThenUpdatesCheckTimestamp() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)
        let oldDate = Date(timeIntervalSinceNow: -(26 * 60 * 60))
        var manifest = CodexBinaryManifest.default
        manifest.lastUpdateCheckAt = oldDate
        manifest.updateState = .idle
        _ = try await manager.saveManifest(manifest)

        // When
        let result = await manager.checkForRustReleaseUpdateIfNeeded(force: false)

        // Then
        let refreshed = try XCTUnwrap(result.lastUpdateCheckAt)
        XCTAssertGreaterThan(refreshed.timeIntervalSince(oldDate), 60)
        XCTAssertNotEqual(result.updateState, .checking)
    }

    func testBDD_GivenLaunchEnvironment_WhenSavingVariable_ThenManifestPersistsIt() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)

        // When
        try await manager.setLaunchEnvironmentValue("1", forKey: "CODEX_DEBUG")
        let manifest = try await manager.loadManifest()

        // Then
        XCTAssertEqual(manifest.launchEnvironment["CODEX_DEBUG"], "1")
    }

    func testBDD_GivenLaunchEnvironment_WhenBuildingCLILaunchCommand_ThenIncludesCodexHomeAndVariables() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)
        try await manager.setLaunchEnvironmentValue("bar", forKey: "FOO")

        // When
        let command = try await manager.cliLaunchCommand(codexHomePath: "/tmp/codex-home")

        // Then
        XCTAssertTrue(command.contains("CODEX_HOME=\"/tmp/codex-home\""))
        XCTAssertTrue(command.contains("FOO=\"bar\""))
    }

    func testBDD_GivenInvalidEnvironmentKey_WhenSavingVariable_ThenThrowsError() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)

        // When / Then
        do {
            try await manager.setLaunchEnvironmentValue("1", forKey: "BAD-KEY")
            XCTFail("Expected invalid key to throw error.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("invalid"))
        }
    }

    func testBDD_GivenReservedEnvironmentKey_WhenSavingVariable_ThenThrowsError() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = CodexBinaryManager(homeURL: root)

        // When / Then
        do {
            try await manager.setLaunchEnvironmentValue("/tmp/a", forKey: "CODEX_HOME")
            XCTFail("Expected reserved key to throw error.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("reserved"))
        }
    }

    func testBDD_GivenNoManagedBinary_WhenBuildingCLILaunchCommand_ThenFallsBackToCodexInPath() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = CodexBinaryManager(homeURL: root)

        // When
        let command = try await manager.cliLaunchCommand(codexHomePath: "/tmp/codex-home", arguments: ["login"])

        // Then
        XCTAssertTrue(command.contains(" codex \"login\""))
        let activeCLIPath = await manager.activeCLIPathIfAvailable()
        XCTAssertNil(activeCLIPath)
    }

    func testBDD_GivenLegacyManifest_WhenDecoding_ThenNewFieldsUseDefaults() throws {
        // Given
        let json = """
        {
          "schemaVersion": 1,
          "selectedVersionId": null,
          "syncModelOnSwitch": false,
          "preferredModel": null,
          "versions": [],
          "updateState": "idle"
        }
        """

        // When
        let decoded = try JSONDecoder().decode(CodexBinaryManifest.self, from: Data(json.utf8))

        // Then
        XCTAssertEqual(decoded.launchEnvironment, [:])
        XCTAssertNil(decoded.preferredTerminalBundleID)
        XCTAssertFalse(decoded.includeBetaVersions)
    }

    func testBDD_GivenTerminalOptions_WhenResolvingTarget_ThenUsesExplicitThenPreferredThenFirst() {
        // Given
        let available: [CodexTerminalApp] = [.terminal, .iTerm]

        // When / Then
        XCTAssertEqual(
            CodexTerminalApp.resolveTarget(
                explicit: .iTerm,
                preferredBundleID: CodexTerminalApp.terminal.bundleIdentifier,
                available: available
            ),
            .iTerm
        )
        XCTAssertEqual(
            CodexTerminalApp.resolveTarget(
                explicit: nil,
                preferredBundleID: CodexTerminalApp.iTerm.bundleIdentifier,
                available: available
            ),
            .iTerm
        )
        XCTAssertEqual(
            CodexTerminalApp.resolveTarget(
                explicit: nil,
                preferredBundleID: "com.unknown.app",
                available: available
            ),
            .terminal
        )
    }

    func testBDD_GivenXcodeBundledBinary_WhenDiscoveringVersions_ThenImportsIntoManifest() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let xcodeBinary = root
            .appendingPathComponent("Library/Developer/Xcode/CodingAssistant/Agents/Versions/26.3/codex")
        try FileManager.default.createDirectory(at: xcodeBinary.deletingLastPathComponent(), withIntermediateDirectories: true)

        let script = "#!/bin/sh\necho \"codex 0.98.0\"\n"
        try script.write(to: xcodeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: xcodeBinary.path)

        let manager = CodexBinaryManager(homeURL: root)

        // When
        let importedCount = try await manager.discoverXcodeAgentVersions()
        let manifest = try await manager.loadManifest()

        // Then
        XCTAssertEqual(importedCount, 1)
        XCTAssertEqual(manifest.versions.count, 1)
        XCTAssertEqual(manifest.versions.first?.source, "xcode-agent")
    }

    func testBDD_GivenIncludeBetaToggle_WhenSaving_ThenManifestPersistsIt() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)

        // When
        try await manager.setIncludeBetaVersions(true)
        let manifest = try await manager.loadManifest()

        // Then
        XCTAssertTrue(manifest.includeBetaVersions)
    }

    func testBDD_GivenIncludeBetaFlag_WhenEncodingAndDecoding_ThenValueIsPreserved() throws {
        // Given
        var manifest = CodexBinaryManifest.default
        manifest.includeBetaVersions = true

        // When
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(CodexBinaryManifest.self, from: data)

        // Then
        XCTAssertTrue(decoded.includeBetaVersions)
    }

    func testBDD_GivenAlreadyImportedXcodeBinary_WhenDiscoveringAgain_ThenDoesNotDuplicate() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let xcodeBinary = root
            .appendingPathComponent("Library/Developer/Xcode/CodingAssistant/Agents/Versions/26.3/codex")
        try FileManager.default.createDirectory(at: xcodeBinary.deletingLastPathComponent(), withIntermediateDirectories: true)
        let script = "#!/bin/sh\necho \"codex 0.98.0\"\n"
        try script.write(to: xcodeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: xcodeBinary.path)

        let manager = CodexBinaryManager(homeURL: root)
        _ = try await manager.discoverXcodeAgentVersions()

        // When
        let secondImportedCount = try await manager.discoverXcodeAgentVersions()
        let manifest = try await manager.loadManifest()

        // Then
        XCTAssertEqual(secondImportedCount, 0)
        XCTAssertEqual(manifest.versions.count, 1)
    }

    func testBDD_GivenNoXcodeAgentFolder_WhenDiscoveringVersions_ThenReturnsZero() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = CodexBinaryManager(homeURL: root)

        // When
        let importedCount = try await manager.discoverXcodeAgentVersions()
        let manifest = try await manager.loadManifest()

        // Then
        XCTAssertEqual(importedCount, 0)
        XCTAssertTrue(manifest.versions.isEmpty)
    }

    func testBDD_GivenStableVersionString_WhenValidating_ThenReturnsTrue() {
        XCTAssertTrue(CodexBinaryManager.isStableVersion("0.98.0"))
    }

    func testBDD_GivenPreReleaseVersionString_WhenValidating_ThenReturnsFalse() {
        XCTAssertFalse(CodexBinaryManager.isStableVersion("0.99.0-rc1"))
    }

    func testBDD_GivenTerminalSupportList_WhenReadingAllCases_ThenContainsWarpAndGhostty() {
        let apps = Set(CodexTerminalApp.allCases)
        XCTAssertTrue(apps.contains(.warp))
        XCTAssertTrue(apps.contains(.ghostty))
    }

    func testBDD_GivenCustomConfigFile_WhenApplyingModel_ThenWritesToCustomPathInsteadOfXcodePath() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)
        let customConfig = STFile(root.appendingPathComponent(".codex/config.toml"))

        // When
        try await manager.applyModelToConfig("gpt-5.3-codex", configFile: customConfig)

        // Then
        let customContent = try String(contentsOf: customConfig.url, encoding: .utf8)
        XCTAssertTrue(customContent.contains("model = \"gpt-5.3-codex\""))

        let xcodeConfig = root.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex/config.toml")
        XCTAssertFalse(FileManager.default.fileExists(atPath: xcodeConfig.path))
    }

    func testBDD_GivenNoSelectedVersionButManagedCLIExists_WhenReadingCurrentCLIVersion_ThenReturnsDetectedVersion() async throws {
        // Given
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(homeURL: root)
        let shim = root.appendingPathComponent(".nolon/codex/bin/codex")
        try FileManager.default.createDirectory(at: shim.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\necho \"codex 0.99.1\"\n".write(to: shim, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: shim.path)

        // When
        let version = try await manager.currentCLIVersion()

        // Then
        XCTAssertEqual(version, "0.99.1")
    }

}

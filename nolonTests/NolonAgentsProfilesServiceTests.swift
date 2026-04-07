import XCTest
import NolonResourceKit
import STFilePath
@testable import nolon

final class NolonAgentsProfilesServiceTests: XCTestCase {
    private var tempRoot: URL!
    private var service: NolonAgentsProfilesService!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-agents-profiles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let manager = NolonManager(rootURL: tempRoot)
        service = NolonAgentsProfilesService(nolonManager: manager)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testBDD_GivenProfilesAndPrimaryAgents_WhenListingProfiles_ThenPrimaryIsActive() throws {
        let folder = tempRoot.appendingPathComponent("agents", isDirectory: true)
        try "# Primary".write(to: folder.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# P1".write(to: folder.appendingPathComponent("AGENTS.profile-1.md"), atomically: true, encoding: .utf8)

        let profiles = try service.listProfiles()

        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.first(where: { $0.fileName == "AGENTS.md" })?.isActive, true)
        XCTAssertEqual(profiles.first(where: { $0.fileName == "AGENTS.profile-1.md" })?.isActive, false)
    }

    func testBDD_GivenSecondaryProfile_WhenActivating_ThenPrimaryBecomesSymlinkToProfile() throws {
        let folder = tempRoot.appendingPathComponent("agents", isDirectory: true)
        let primary = folder.appendingPathComponent("AGENTS.md")
        let profile = folder.appendingPathComponent("AGENTS.profile-1.md")
        try "# Primary".write(to: primary, atomically: true, encoding: .utf8)
        try "# P1".write(to: profile, atomically: true, encoding: .utf8)

        try service.activateProfile(at: profile.path)

        XCTAssertTrue(STPath(primary).isSymbolicLink)
        let listed = try service.listProfiles()
        XCTAssertEqual(listed.first(where: { $0.fileName == "AGENTS.profile-1.md" })?.isActive, true)
    }

    func testBDD_GivenActiveProfileSymlink_WhenDeletingActiveProfile_ThenPrimaryFallsBackToRegularFile() throws {
        let folder = tempRoot.appendingPathComponent("agents", isDirectory: true)
        let primary = folder.appendingPathComponent("AGENTS.md")
        let profile = folder.appendingPathComponent("AGENTS.profile-1.md")
        try "# Primary".write(to: primary, atomically: true, encoding: .utf8)
        try "# P1".write(to: profile, atomically: true, encoding: .utf8)
        try service.activateProfile(at: profile.path)

        try service.deleteProfile(at: profile.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: primary.path))
        XCTAssertFalse(STPath(primary).isSymbolicLink)
    }
}

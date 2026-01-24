import XCTest
@testable import nolon

final class RemoteRepositoryTests: XCTestCase {
    
    // MARK: - normalizeGitURL Tests
    
    func testNormalizeGitURL_OwnerRepoShorthand() {
        XCTAssertEqual(
            RemoteRepository.normalizeGitURL("vercel/agent-skills"),
            "https://github.com/vercel/agent-skills.git"
        )
        XCTAssertEqual(
            RemoteRepository.normalizeGitURL("owner/repo"),
            "https://github.com/owner/repo.git"
        )
    }
    
    func testNormalizeGitURL_OwnerRepoSubpath() {
        // subpath 格式也应转换为 GitHub URL (subpath 通过 extractSubpath 单独获取)
        XCTAssertEqual(
            RemoteRepository.normalizeGitURL("owner/repo/skills/my-skill"),
            "https://github.com/owner/repo.git"
        )
    }
    
    func testNormalizeGitURL_FullHTTPSURL() {
        let url = "https://github.com/owner/repo"
        XCTAssertEqual(RemoteRepository.normalizeGitURL(url), url)
        
        let urlWithGit = "https://github.com/owner/repo.git"
        XCTAssertEqual(RemoteRepository.normalizeGitURL(urlWithGit), urlWithGit)
    }
    
    func testNormalizeGitURL_SSHFormat() {
        let ssh = "git@github.com:owner/repo.git"
        XCTAssertEqual(RemoteRepository.normalizeGitURL(ssh), ssh)
    }
    
    func testNormalizeGitURL_GitLabURL() {
        let gitlab = "https://gitlab.com/owner/repo"
        XCTAssertEqual(RemoteRepository.normalizeGitURL(gitlab), gitlab)
    }
    
    func testNormalizeGitURL_LocalPath() {
        XCTAssertEqual(RemoteRepository.normalizeGitURL("./skills"), "./skills")
        XCTAssertEqual(RemoteRepository.normalizeGitURL("/absolute/path"), "/absolute/path")
        XCTAssertEqual(RemoteRepository.normalizeGitURL("~/Documents/skills"), "~/Documents/skills")
    }
    
    func testNormalizeGitURL_TrimsWhitespace() {
        XCTAssertEqual(
            RemoteRepository.normalizeGitURL("  owner/repo  "),
            "https://github.com/owner/repo.git"
        )
    }
    
    // MARK: - extractSubpath Tests
    
    func testExtractSubpath_WithSubpath() {
        XCTAssertEqual(
            RemoteRepository.extractSubpath(from: "owner/repo/skills/my-skill"),
            "skills/my-skill"
        )
        XCTAssertEqual(
            RemoteRepository.extractSubpath(from: "owner/repo/deep/nested/path"),
            "deep/nested/path"
        )
    }
    
    func testExtractSubpath_NoSubpath() {
        XCTAssertNil(RemoteRepository.extractSubpath(from: "owner/repo"))
    }
    
    func testExtractSubpath_FullURL() {
        // 完整 URL 不应提取 subpath (需要使用 URL 解析)
        XCTAssertNil(RemoteRepository.extractSubpath(from: "https://github.com/owner/repo"))
    }
    
    func testExtractSubpath_LocalPath() {
        XCTAssertNil(RemoteRepository.extractSubpath(from: "./local/path"))
        XCTAssertNil(RemoteRepository.extractSubpath(from: "/absolute/path"))
    }
}

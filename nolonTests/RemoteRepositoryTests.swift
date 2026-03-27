import XCTest
import NolonResourceKit
@testable import nolon

final class RemoteRepositoryTests: XCTestCase {
    
    // MARK: - normalizeGitURL Tests
    
    func testNormalizeGitURL_OwnerRepoShorthand() {
        XCTAssertEqual(
            SkillsRepositoryFacade.normalizeGitURL("vercel/agent-skills"),
            "https://github.com/vercel/agent-skills.git"
        )
        XCTAssertEqual(
            SkillsRepositoryFacade.normalizeGitURL("owner/repo"),
            "https://github.com/owner/repo.git"
        )
    }
    
    func testNormalizeGitURL_OwnerRepoSubpath() {
        // subpath 格式也应转换为 GitHub URL (subpath 通过 extractSubpath 单独获取)
        XCTAssertEqual(
            SkillsRepositoryFacade.normalizeGitURL("owner/repo/skills/my-skill"),
            "https://github.com/owner/repo.git"
        )
    }
    
    func testNormalizeGitURL_FullHTTPSURL() {
        let url = "https://github.com/owner/repo"
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL(url), "https://github.com/owner/repo.git")
        
        let urlWithGit = "https://github.com/owner/repo.git"
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL(urlWithGit), urlWithGit)
    }
    
    func testNormalizeGitURL_SSHFormat() {
        let ssh = "git@github.com:owner/repo.git"
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL(ssh), ssh)
    }
    
    func testNormalizeGitURL_GitLabURL() {
        let gitlab = "https://gitlab.com/owner/repo"
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL(gitlab), "https://gitlab.com/owner/repo.git")
    }

    func testNormalizeGitURL_GitLabNestedGroupURL() {
        let gitlabNested = "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group"
        XCTAssertEqual(
            SkillsRepositoryFacade.normalizeGitURL(gitlabNested),
            "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group.git"
        )
    }
    
    func testNormalizeGitURL_LocalPath() {
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL("./skills"), "./skills")
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL("/absolute/path"), "/absolute/path")
        XCTAssertEqual(SkillsRepositoryFacade.normalizeGitURL("~/Documents/skills"), "~/Documents/skills")
    }
    
    func testNormalizeGitURL_TrimsWhitespace() {
        XCTAssertEqual(
            SkillsRepositoryFacade.normalizeGitURL("  owner/repo  "),
            "https://github.com/owner/repo.git"
        )
    }
    
    // MARK: - extractSubpath Tests
    
    func testExtractSubpath_WithSubpath() {
        XCTAssertEqual(
            SkillsRepositoryFacade.extractSubpath(from: "owner/repo/skills/my-skill"),
            "skills/my-skill"
        )
        XCTAssertEqual(
            SkillsRepositoryFacade.extractSubpath(from: "owner/repo/deep/nested/path"),
            "deep/nested/path"
        )
    }
    
    func testExtractSubpath_NoSubpath() {
        XCTAssertNil(SkillsRepositoryFacade.extractSubpath(from: "owner/repo"))
    }
    
    func testExtractSubpath_FullURL() {
        // 完整 URL 不应提取 subpath (需要使用 URL 解析)
        XCTAssertNil(SkillsRepositoryFacade.extractSubpath(from: "https://github.com/owner/repo"))
    }

    func testExtractSubpath_GitLabNestedGroupURL() {
        XCTAssertNil(
            SkillsRepositoryFacade.extractSubpath(
                from: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group"
            )
        )
        XCTAssertEqual(
            SkillsRepositoryFacade.extractSubpath(
                from: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group/-/tree/main/skills/web"
            ),
            "skills/web"
        )
    }
    
    func testExtractSubpath_LocalPath() {
        XCTAssertNil(SkillsRepositoryFacade.extractSubpath(from: "./local/path"))
        XCTAssertNil(SkillsRepositoryFacade.extractSubpath(from: "/absolute/path"))
    }

    // MARK: - Repository Identity Tests

    func testExtractRepoName_FromShorthandAndSSH() {
        XCTAssertEqual(
            RemoteRepository.extractRepoName(from: "vercel/agent-skills"),
            "agent-skills"
        )
        XCTAssertEqual(
            RemoteRepository.extractRepoName(from: "git@gitlab.example.com:team/repo.git"),
            "repo"
        )
        XCTAssertEqual(
            RemoteRepository.extractRepoName(
                from: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group"
            ),
            "axure-skill-group"
        )
    }

    func testExtractRepoFullName_FromShorthandAndHTTPS() {
        XCTAssertEqual(
            RemoteRepository.extractRepoFullName(from: "vercel/agent-skills"),
            "vercel@agent-skills"
        )
        XCTAssertEqual(
            RemoteRepository.extractRepoFullName(from: "https://github.com/openai/codex.git"),
            "openai@codex"
        )
    }

    func testDetectProvider_UsesFacadeSemantics() {
        XCTAssertEqual(
            RemoteRepository.detectProvider(from: "https://github.com/openai/codex.git"),
            .github
        )
        XCTAssertEqual(
            RemoteRepository.detectProvider(from: "git@gitlab.example.com:team/repo.git"),
            .gitlab
        )
        XCTAssertEqual(
            RemoteRepository.detectProvider(from: "https://bitbucket.org/team/repo.git"),
            .bitbucket
        )
    }

    func testGlobalSkillsPath_UsesNolonSkillsFolder() {
        let repo = RemoteRepository(
            id: "global",
            name: "Global",
            baseURL: "https://example.com",
            iconName: "globe",
            logoName: nil,
            templateType: .globalSkills,
            isBuiltIn: true
        )

        XCTAssertEqual(repo.effectiveSkillsPaths.count, 1)
        XCTAssertTrue(repo.effectiveSkillsPaths[0].hasSuffix("/.nolon/skills"))
    }

    func testLocalClonePath_ForGitRepository_UsesRepositoriesLayout() {
        let repo = RemoteRepository(
            id: "git",
            name: "Git",
            baseURL: "https://example.com",
            iconName: "globe",
            logoName: nil,
            templateType: .git,
            isBuiltIn: false,
            localPath: nil,
            gitURL: "vercel/agent-skills",
            provider: .github
        )

        let path = repo.localClonePath.path
        XCTAssertTrue(path.contains("/.nolon/repositories/"))
        XCTAssertTrue(path.hasSuffix("/github.com/vercel@agent-skills"))
    }
}

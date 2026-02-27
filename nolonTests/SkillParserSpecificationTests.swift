import XCTest
import NolonResourceKit
@testable import nolon
import ProviderCatalog

final class SkillParserSpecificationTests: XCTestCase {

    func testParseStandardMetadata_WithSpecFields() throws {
        let content = """
        ---
        name: agent-browser
        description: Browser automation skill for web tasks.
        license: MIT
        metadata:
          author: openai
          version: 1.2.3
          argument-hint: <url>
        ---

        # Agent Browser
        """

        let parsed = try XCTUnwrap(
            SkillParser.parseStandardMetadata(content: content, directoryName: "agent-browser")
        )

        XCTAssertEqual(parsed.name, "agent-browser")
        XCTAssertEqual(parsed.description, "Browser automation skill for web tasks.")
        XCTAssertEqual(parsed.license, "MIT")
        XCTAssertEqual(parsed.compatibility, nil)
        XCTAssertEqual(parsed.metadata["author"], "openai")
        XCTAssertEqual(parsed.metadata["version"], "1.2.3")
        XCTAssertEqual(parsed.argumentHint, "<url>")
        XCTAssertTrue(parsed.allowedTools.isEmpty)
        XCTAssertTrue(parsed.warnings.isEmpty)
    }

    func testParseStandardMetadata_NameMismatchWarns() throws {
        let content = """
        ---
        name: browser-agent
        description: Browser automation skill.
        ---

        # Browser Agent
        """

        let parsed = try XCTUnwrap(
            SkillParser.parseStandardMetadata(content: content, directoryName: "agent-browser")
        )

        XCTAssertTrue(parsed.warnings.contains { $0.contains("directory") })
    }

    func testParseStandardMetadata_InvalidNameReportsErrorIssue() throws {
        let content = """
        ---
        name: Agent Browser
        description: Browser automation skill.
        ---

        # Browser Agent
        """

        let parsed = try XCTUnwrap(
            SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "Agent Browser")
        )

        XCTAssertTrue(
            parsed.issues.contains {
                $0.code == .invalidNameFormat && $0.severity == .error
            }
        )
    }

    func testParseStandardMetadata_CompatibilityAndAllowedTools() throws {
        let content = """
        ---
        name: vercel-deploy
        description: Deploy applications and websites.
        compatibility: Works with Codex, Claude, and Cursor.
        allowed-tools: Bash(git:*) Read Write
        ---

        # Deploy
        """

        let parsed = try XCTUnwrap(
            SkillParser.parseStandardMetadata(content: content, directoryName: "vercel-deploy")
        )

        XCTAssertEqual(parsed.compatibility, "Works with Codex, Claude, and Cursor.")
        XCTAssertEqual(parsed.allowedTools, ["Bash(git:*)", "Read", "Write"])
    }

    func testParse_LegacyNoFrontmatterStillWorks() throws {
        let content = """
        # Legacy Skill

        No frontmatter here.
        """

        let parsed = try SkillParser.parse(
            content: content,
            id: "legacy-skill",
            globalPath: "/tmp/legacy-skill"
        )

        XCTAssertEqual(parsed.name, "legacy-skill")
        XCTAssertEqual(parsed.description, "No description available")
    }
}

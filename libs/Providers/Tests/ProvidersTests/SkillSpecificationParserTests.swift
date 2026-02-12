import Foundation
import Testing
@testable import ProviderCatalog

@Suite("SkillSpecificationParser")
struct SkillSpecificationParserTests {
    @Test("parse standard metadata from frontmatter")
    func parseStandardMetadata() {
        let content = """
        ---
        name: agent-browser
        description: Browser automation skill for web tasks.
        license: MIT
        compatibility: codex, claude
        allowed-tools: Bash(git:*) Read Write
        metadata:
          author: openai
          argument-hint: <url>
        ---

        # Agent Browser
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "agent-browser")
        #expect(parsed != nil)
        #expect(parsed?.name == "agent-browser")
        #expect(parsed?.description == "Browser automation skill for web tasks.")
        #expect(parsed?.license == "MIT")
        #expect(parsed?.compatibility == "codex, claude")
        #expect(parsed?.allowedTools == ["Bash(git:*)", "Read", "Write"])
        #expect(parsed?.metadata["author"] == "openai")
        #expect(parsed?.metadata["argument-hint"] == "<url>")
        #expect(parsed?.isValid == true)
        #expect(parsed?.issues.isEmpty == true)
    }

    @Test("fallback to directory when name missing")
    func fallbackDirectoryName() {
        let content = """
        ---
        description: Skill without name.
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "fallback-skill")
        #expect(parsed?.name == "fallback-skill")
        #expect(parsed?.isValid == false)
        #expect(parsed?.issues.contains { $0.code == .missingName && $0.severity == .error } == true)
    }

    @Test("extract skill display name prefers metadata name")
    func extractSkillDisplayName() {
        let content = """
        ---
        name: better-skill-name
        description: Example.
        ---
        """

        #expect(
            SkillSpecificationParser.extractSkillDisplayName(
                from: content,
                fallbackDirectoryName: "folder-name"
            ) == "better-skill-name"
        )
    }

    @Test("parse block description and mixed metadata values")
    func parseBlockDescriptionAndMixedMetadataValues() {
        let content = """
        ---
        name: skill-parser
        description: |
          line one
          line two
        metadata:
          retries: 3
          owner: team-a
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "skill-parser")
        #expect(parsed?.description == "line one\nline two")
        #expect(parsed?.metadata["owner"] == "team-a")
        #expect(parsed?.metadata["retries"] == "3")
        #expect(parsed?.warnings.contains { $0.contains("retries") } == true)
    }

    @Test("warn invalid name format")
    func warnInvalidName() {
        let content = """
        ---
        name: Invalid Name
        description: desc
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "invalid-name")
        #expect(parsed?.isValid == false)
        #expect(parsed?.issues.contains { $0.code == .invalidNameFormat && $0.severity == .error } == true)
    }

    @Test("parse allowed tools from yaml list")
    func parseAllowedToolsFromArray() {
        let content = """
        ---
        name: array-tools
        description: desc
        allowed-tools:
          - Read
          - Write
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "array-tools")
        #expect(parsed?.allowedTools == ["Read", "Write"])
    }

    @Test("warn unknown top level fields")
    func warnUnknownTopLevelFields() {
        let content = """
        ---
        name: skill-with-extra
        description: desc
        unexpected-key: value
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "skill-with-extra")
        #expect(parsed?.issues.contains { $0.code == .unknownTopLevelField && $0.severity == .warning } == true)
    }

    @Test("warn empty required fields")
    func warnEmptyRequiredFields() {
        let content = """
        ---
        name: "   "
        description: ""
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "fallback-name")
        #expect(parsed?.name == "fallback-name")
        #expect(parsed?.isValid == false)
        #expect(parsed?.issues.contains { $0.code == .missingName && $0.severity == .error } == true)
        #expect(parsed?.issues.contains { $0.code == .missingDescription && $0.severity == .error } == true)
    }

    @Test("parse allowed tools from comma separated and mixed yaml list")
    func parseAllowedToolsFlexibleInput() {
        let fromString = """
        ---
        name: string-tools
        description: desc
        allowed-tools: Read, Write, Bash(git:*)
        ---
        """
        let stringParsed = SkillSpecificationParser.parseStandardMetadata(from: fromString, directoryName: "string-tools")
        #expect(stringParsed?.allowedTools == ["Read", "Write", "Bash(git:*)"])

        let fromMixedArray = """
        ---
        name: mixed-array-tools
        description: desc
        allowed-tools:
          - Read
          - 1
          - Write
        ---
        """
        let mixedParsed = SkillSpecificationParser.parseStandardMetadata(from: fromMixedArray, directoryName: "mixed-array-tools")
        #expect(mixedParsed?.allowedTools == ["Read", "1", "Write"])
        #expect(mixedParsed?.issues.contains { $0.code == .allowedToolsNonStringItem && $0.severity == .warning } == true)
    }

    @Test("invalid when description missing from frontmatter")
    func missingDescriptionIsError() {
        let content = """
        ---
        name: missing-description
        ---
        """

        let parsed = SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: "missing-description")
        #expect(parsed?.isValid == false)
        #expect(parsed?.issues.contains { $0.code == .missingDescription && $0.severity == .error } == true)
    }
}

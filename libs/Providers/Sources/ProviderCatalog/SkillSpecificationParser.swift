import Foundation
import Yams

/// Parser for SKILL.md frontmatter based on the Agent Skills specification.
/// Reference: https://agentskills.io/specification
public enum SkillSpecificationParser {
    public enum IssueSeverity: String, Sendable, Equatable, Codable {
        case warning
        case error
    }

    public enum IssueCode: String, Sendable, Equatable, Codable {
        case unknownTopLevelField = "unknown_top_level_field"
        case metadataNotObject = "metadata_not_object"
        case metadataValueNotString = "metadata_value_not_string"
        case missingName = "missing_name"
        case missingDescription = "missing_description"
        case invalidNameFormat = "invalid_name_format"
        case nameDirectoryMismatch = "name_directory_mismatch"
        case descriptionTooLong = "description_too_long"
        case compatibilityOutOfRange = "compatibility_out_of_range"
        case allowedToolsUnsupportedFormat = "allowed_tools_unsupported_format"
        case allowedToolsNonStringItem = "allowed_tools_non_string_item"
    }

    public struct ValidationIssue: Sendable, Equatable, Codable {
        public let code: IssueCode
        public let severity: IssueSeverity
        public let message: String

        public init(code: IssueCode, severity: IssueSeverity, message: String) {
            self.code = code
            self.severity = severity
            self.message = message
        }
    }

    private static let knownTopLevelKeys: Set<String> = [
        "name",
        "description",
        "license",
        "compatibility",
        "metadata",
        "argument-hint",
        "allowed-tools"
    ]

    public struct StandardMetadata: Sendable, Equatable {
        public let name: String
        public let description: String
        public let license: String?
        public let compatibility: String?
        public let metadata: [String: String]
        public let argumentHint: String?
        public let allowedTools: [String]
        public let warnings: [String]
        public let issues: [ValidationIssue]

        public var isValid: Bool {
            !issues.contains(where: { $0.severity == .error })
        }

        public init(
            name: String,
            description: String,
            license: String?,
            compatibility: String?,
            metadata: [String: String],
            argumentHint: String?,
            allowedTools: [String],
            warnings: [String],
            issues: [ValidationIssue]
        ) {
            self.name = name
            self.description = description
            self.license = license
            self.compatibility = compatibility
            self.metadata = metadata
            self.argumentHint = argumentHint
            self.allowedTools = allowedTools
            self.warnings = warnings
            self.issues = issues
        }
    }

    public static func extractSkillDisplayName(from content: String, fallbackDirectoryName: String) -> String {
        if let metadata = parseStandardMetadata(from: content, directoryName: fallbackDirectoryName),
           !metadata.name.isEmpty
        {
            return metadata.name
        }
        return fallbackDirectoryName
    }

    public static func parseStandardMetadata(from content: String, directoryName: String?) -> StandardMetadata? {
        guard let frontmatter = extractFrontmatter(from: content) else { return nil }
        guard let rawTopLevel = try? Yams.load(yaml: frontmatter) as? [String: Any] else { return nil }

        var issues: [ValidationIssue] = []
        var metadata: [String: String] = [:]
        let unknownTopLevelKeys = Set(rawTopLevel.keys).subtracting(knownTopLevelKeys)
        if !unknownTopLevelKeys.isEmpty {
            for key in unknownTopLevelKeys.sorted() {
                issues.append(
                    ValidationIssue(
                        code: .unknownTopLevelField,
                        severity: .warning,
                        message: "unknown top-level field '\(key)'"
                    )
                )
            }
        }

        if let rawMetadata = rawTopLevel["metadata"] {
            if let metadataMap = rawMetadata as? [String: Any] {
                for (key, value) in metadataMap {
                    if let stringValue = value as? String {
                        metadata[key] = stringValue
                    } else {
                        metadata[key] = String(describing: value)
                        issues.append(
                            ValidationIssue(
                                code: .metadataValueNotString,
                                severity: .warning,
                                message: "metadata value for '\(key)' is not string"
                            )
                        )
                    }
                }
            } else {
                issues.append(
                    ValidationIssue(
                        code: .metadataNotObject,
                        severity: .warning,
                        message: "metadata is not an object"
                    )
                )
            }
        }

        let parsedName = normalizeString(rawTopLevel["name"])
        let parsedDescription = normalizeString(rawTopLevel["description"])
        let parsedLicense = normalizeString(rawTopLevel["license"])
        let parsedCompatibility = normalizeString(rawTopLevel["compatibility"])
        let parsedArgumentHint = normalizeString(rawTopLevel["argument-hint"]) ?? metadata["argument-hint"]
        let allowedToolsResult = parseAllowedTools(rawTopLevel["allowed-tools"])
        issues.append(contentsOf: allowedToolsResult.issues)
        let allowedTools = allowedToolsResult.items

        let effectiveName = parsedName?.isEmpty == false ? parsedName : nil
        let name = (effectiveName ?? directoryName) ?? ""
        let description = parsedDescription ?? ""

        if parsedName == nil {
            issues.append(
                ValidationIssue(
                    code: .missingName,
                    severity: .error,
                    message: "missing name in frontmatter"
                )
            )
        } else if parsedName?.isEmpty == true {
            issues.append(
                ValidationIssue(
                    code: .missingName,
                    severity: .error,
                    message: "empty name in frontmatter"
                )
            )
        }
        if parsedDescription == nil {
            issues.append(
                ValidationIssue(
                    code: .missingDescription,
                    severity: .error,
                    message: "missing description in frontmatter"
                )
            )
        } else if parsedDescription?.isEmpty == true {
            issues.append(
                ValidationIssue(
                    code: .missingDescription,
                    severity: .error,
                    message: "empty description in frontmatter"
                )
            )
        }

        if !name.isEmpty {
            let isValidName = isSkillNameValid(name)
            if !isValidName {
                issues.append(
                    ValidationIssue(
                        code: .invalidNameFormat,
                        severity: .error,
                        message: "invalid name format"
                    )
                )
            }
        }

        if let directoryName,
           !directoryName.isEmpty,
           !name.isEmpty,
           directoryName != name
        {
            issues.append(
                ValidationIssue(
                    code: .nameDirectoryMismatch,
                    severity: .warning,
                    message: "name does not match directory"
                )
            )
        }

        if description.count > 1024 {
            issues.append(
                ValidationIssue(
                    code: .descriptionTooLong,
                    severity: .warning,
                    message: "description exceeds recommended length"
                )
            )
        }

        let compatibility = parsedCompatibility
        if let compatibility,
           (compatibility.isEmpty || compatibility.count > 500)
        {
            issues.append(
                ValidationIssue(
                    code: .compatibilityOutOfRange,
                    severity: .warning,
                    message: "compatibility is out of range"
                )
            )
        }
        let warnings = issues.filter { $0.severity == .warning }.map(\.message)

        return StandardMetadata(
            name: name,
            description: description,
            license: parsedLicense,
            compatibility: compatibility,
            metadata: metadata,
            argumentHint: parsedArgumentHint,
            allowedTools: allowedTools,
            warnings: warnings,
            issues: issues
        )
    }

    private static func normalizeString(_ value: Any?) -> String? {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value {
            return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func parseAllowedTools(_ value: Any?) -> (items: [String], issues: [ValidationIssue]) {
        guard let value else { return ([], []) }
        if let string = value as? String {
            let values = string
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return (values, [])
        }
        if let array = value as? [String] {
            return (
                array
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                []
            )
        }
        if let array = value as? [Any] {
            var issues: [ValidationIssue] = []
            let values = array.compactMap { item -> String? in
                if let string = item as? String {
                    let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    return normalized.isEmpty ? nil : normalized
                }
                issues.append(
                    ValidationIssue(
                        code: .allowedToolsNonStringItem,
                        severity: .warning,
                        message: "allowed-tools contains non-string item"
                    )
                )
                let normalized = String(describing: item).trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            }
            return (values, issues)
        }
        return (
            [],
            [
                ValidationIssue(
                    code: .allowedToolsUnsupportedFormat,
                    severity: .warning,
                    message: "allowed-tools format is unsupported"
                ),
            ]
        )
    }

    private static func isSkillNameValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64 else { return false }
        guard name.first != "-", name.last != "-", !name.contains("--") else { return false }

        for scalar in name.unicodeScalars {
            if scalar == "-" { continue }
            if scalar.properties.numericType != nil { continue }
            if scalar.properties.generalCategory == .lowercaseLetter { continue }
            return false
        }
        return true
    }

    private static func extractFrontmatter(from content: String) -> String? {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
              ),
              let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        return String(content[range])
    }
}

import Foundation
import Testing
@testable import CodexProvider

@Suite("Codex EventMsg Schema Drift Guard")
struct CodexEventMsgSchemaDriftGuardTests {
    @Test("EventMsg variants from codex protocol should be covered by provider compatibility set")
    func protocolEventMsgVariantsAreCovered() throws {
        let protocolFile = try protocolFilePath()
        let source = try String(contentsOfFile: protocolFile, encoding: .utf8)
        let variants = try extractEventMsgVariants(from: source)
        #expect(!variants.isEmpty)

        var expectedTypes = Set(variants.map(eventTypeName(fromVariant:)))
        if variants.contains("TurnStarted") {
            expectedTypes.insert("turn_started")
        }
        if variants.contains("TurnComplete") {
            expectedTypes.insert("turn_complete")
        }

        let supported = CodexGeneratedFilesParser.supportedEventMessageTypesForCompatibility
        let missing = expectedTypes.subtracting(supported).sorted()
        #expect(missing.isEmpty, "Missing compatible event_msg types: \(missing.joined(separator: ", "))")
    }

    private func protocolFilePath() throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        // .../libs/Providers/Tests/ProvidersTests/CodexTests/<file>.swift -> repo root
        let root = here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let target = root.appendingPathComponent("libs/codex/codex-rs/protocol/src/protocol.rs").path
        guard FileManager.default.fileExists(atPath: target) else {
            throw NSError(domain: "CodexEventMsgSchemaDriftGuardTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "protocol.rs not found: \(target)",
            ])
        }
        return target
    }

    private func extractEventMsgVariants(from source: String) throws -> [String] {
        guard let enumRange = source.range(of: "pub enum EventMsg {") else {
            throw NSError(domain: "CodexEventMsgSchemaDriftGuardTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "pub enum EventMsg not found",
            ])
        }
        let tail = source[enumRange.upperBound...]
        guard let endRange = tail.range(of: "\n}\n\nimpl ") else {
            throw NSError(domain: "CodexEventMsgSchemaDriftGuardTests", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "EventMsg enum end not found",
            ])
        }
        let body = String(tail[..<endRange.lowerBound])

        var variants: [String] = []
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("///") || line.hasPrefix("#[") {
                continue
            }
            guard let token = line.split(whereSeparator: { $0 == "(" || $0 == "," }).first else {
                continue
            }
            let name = String(token)
            guard name.first?.isUppercase == true else { continue }
            variants.append(name)
        }
        return variants
    }

    private func eventTypeName(fromVariant variant: String) -> String {
        switch variant {
        case "TurnStarted":
            return "task_started"
        case "TurnComplete":
            return "task_complete"
        default:
            return snakeCase(variant)
        }
    }

    private func snakeCase(_ input: String) -> String {
        var scalars: [Character] = []
        for character in input {
            if character.isUppercase {
                if !scalars.isEmpty {
                    scalars.append("_")
                }
                scalars.append(Character(character.lowercased()))
            } else {
                scalars.append(character)
            }
        }
        return String(scalars)
    }
}

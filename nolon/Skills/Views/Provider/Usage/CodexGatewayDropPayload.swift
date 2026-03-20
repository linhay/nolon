import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct CodexGatewayAccountDropItem: Codable, Hashable, Transferable {
    let accountID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .nolonCodexGatewayAccountID)
    }
}

enum CodexGatewayDropParser {
    private static let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#

    static func accountIDs(fromLegacyStrings items: [String]) -> [UUID] {
        items.compactMap { extractAccountID(fromLegacyString: $0) }
    }

    static func extractAccountID(fromLegacyString raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = UUID(uuidString: trimmed) {
            return direct
        }

        guard let range = trimmed.range(of: uuidPattern, options: .regularExpression) else {
            return nil
        }
        return UUID(uuidString: String(trimmed[range]))
    }
}

private extension UTType {
    static let nolonCodexGatewayAccountID = UTType(exportedAs: "com.nolon.codex.gateway-account-id")
}

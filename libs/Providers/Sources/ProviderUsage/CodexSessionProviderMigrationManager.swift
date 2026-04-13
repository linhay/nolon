import Foundation
import OSLog
import CodexProvider
import STFilePath

struct CodexSessionProviderMigrationManager: Sendable {
    struct Report: Sendable, Equatable {
        var liveRolloutFilesUpdated = 0
        var archivedRolloutFilesUpdated = 0
        var stateRowsUpdated = 0

        var hasChanges: Bool {
            liveRolloutFilesUpdated > 0 || archivedRolloutFilesUpdated > 0 || stateRowsUpdated > 0
        }
    }

    private static let logger = Logger(subsystem: "com.nolon", category: "CodexSessionProviderMigration")
    private let defaultProviderID: String

    init(defaultProviderID: String = "openai") {
        self.defaultProviderID = Self.normalizedProviderID(defaultProviderID) ?? "openai"
    }

    func migrateSessionProviders(
        codexHome: STFolder,
        sourceProviderIDs: [String],
        targetProviderID: String
    ) {
        let service = CodexSessionStore(defaultProviderID: defaultProviderID)
        let report: Report
        do {
            let migration = try service.migrateProviders(
                codexHome: codexHome,
                sourceProviderIDs: sourceProviderIDs,
                targetProviderID: targetProviderID
            )
            report = .init(
                liveRolloutFilesUpdated: migration.liveRolloutFilesUpdated,
                archivedRolloutFilesUpdated: migration.archivedRolloutFilesUpdated,
                stateRowsUpdated: migration.stateRowsUpdated
            )
        } catch {
            Self.logger.error("Failed to migrate Codex history provider metadata. home=\(codexHome.url.path, privacy: .public) error=\(String(describing: error), privacy: .public)")
            return
        }

        guard report.hasChanges else { return }
        Self.logger.info(
            "Migrated Codex history provider metadata. home=\(codexHome.url.path, privacy: .public) target=\(targetProviderID, privacy: .public) sources=\(sourceProviderIDs.joined(separator: ","), privacy: .public) live_files=\(report.liveRolloutFilesUpdated, privacy: .public) archived_files=\(report.archivedRolloutFilesUpdated, privacy: .public) state_rows=\(report.stateRowsUpdated, privacy: .public)"
        )
    }

    private static func normalizedProviderID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }
        return raw.lowercased()
    }
}

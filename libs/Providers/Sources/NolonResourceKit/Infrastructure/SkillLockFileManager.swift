import Foundation
import STFilePath
import OSLog

public actor SkillLockFileManager {
    private static let logger = Logger(subsystem: "com.nolon", category: "SkillLockFileManager")
    
    private let nolonManager: NolonManager
    private var lockFilePath: String {
        "\(nolonManager.rootPath)/.skill-lock.json"
    }
    
    public struct RebuildResult: Sendable, Equatable {
        public let processedCount: Int
        public let addedCount: Int
        public let updatedCount: Int
        public let skippedCount: Int
        
        public init(processedCount: Int, addedCount: Int, updatedCount: Int, skippedCount: Int) {
            self.processedCount = processedCount
            self.addedCount = addedCount
            self.updatedCount = updatedCount
            self.skippedCount = skippedCount
        }
    }
    
    public init(nolonManager: NolonManager = .shared) {
        self.nolonManager = nolonManager
    }
    
    public func readLockFile() async throws -> SkillLockFile {
        let lockPath = STPath(lockFilePath)
        
        guard lockPath.isExists,
              let data = try? STFile(lockFilePath).data() else {
            return SkillLockFile.empty()
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let lockFile = try decoder.decode(SkillLockFile.self, from: data)
            
            if lockFile.version < SkillLockFile.currentVersion {
                let migrated = SkillLockFile(
                    version: SkillLockFile.currentVersion,
                    skills: lockFile.skills,
                    dismissedPrompts: lockFile.dismissedPrompts,
                    lastSelectedProviders: lockFile.lastSelectedProviders
                )
                try? await writeLockFile(migrated)
                return migrated
            }
            
            return lockFile
        } catch {
            return SkillLockFile.empty()
        }
    }
    
    public func writeLockFile(_ lockFile: SkillLockFile) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(lockFile)
        try STFile(lockFilePath).overlay(with: data)
    }
    
    public func resetLockFile() async throws {
        let empty = SkillLockFile.empty()
        try await writeLockFile(empty)
    }
    
    /// Rebuild (or backfill) `.skill-lock.json` by scanning `~/.nolon/skills`.
    /// - Parameter overwriteExisting: If `true`, replaces all existing entries; otherwise preserves existing source metadata and only backfills/refreshes fields.
    /// - Returns: Rebuild statistics.
    public func rebuildFromGlobalSkills(overwriteExisting: Bool) async throws -> RebuildResult {
        let globalSkillsPath = nolonManager.skillsPath
        guard STPath(globalSkillsPath).isExists else {
            return RebuildResult(processedCount: 0, addedCount: 0, updatedCount: 0, skippedCount: 0)
        }
        
        let folders = (try? STFolder(globalSkillsPath).folders()) ?? []
        var lockFile = overwriteExisting ? SkillLockFile.empty() : (try await readLockFile())
        
        var processedCount = 0
        var addedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        let now = Date()
        
        for folder in folders {
            let slug = folder.url.lastPathComponent
            if slug.hasPrefix(".") { continue }
            
            let globalPath = folder.url.path
            let skillMdPath = "\(globalPath)/SKILL.md"
            guard STFile(skillMdPath).isExists, let content = try? STFile(skillMdPath).read() else {
                skippedCount += 1
                continue
            }
            
            processedCount += 1
            
            let parsed: Skill
            do {
                parsed = try SkillParser.parse(content: content, id: slug, globalPath: globalPath)
            } catch {
                Self.logger.error("Failed to parse SKILL.md for \(slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
                skippedCount += 1
                continue
            }
            
            let inferred = inferSourceInfo(forSkillAt: folder.url, slug: slug)
            let existing = lockFile.skills[slug]
            let willAdd = existing == nil
            
            let entry = SkillLockEntry(
                source: overwriteExisting ? inferred.source : (existing?.source ?? inferred.source),
                sourceType: overwriteExisting ? inferred.sourceType : (existing?.sourceType ?? inferred.sourceType),
                sourceUrl: overwriteExisting ? inferred.sourceUrl : (existing?.sourceUrl ?? inferred.sourceUrl),
                skillPath: overwriteExisting ? inferred.skillPath : (existing?.skillPath ?? inferred.skillPath),
                skillFolderHash: overwriteExisting ? nil : existing?.skillFolderHash,
                installedAt: existing?.installedAt ?? now,
                updatedAt: now,
                version: parsed.version,
                displayName: parsed.name
            )
            
            lockFile.skills[slug] = entry
            if willAdd {
                addedCount += 1
            } else {
                updatedCount += 1
            }
        }
        
        try await writeLockFile(lockFile)
        return RebuildResult(
            processedCount: processedCount,
            addedCount: addedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount
        )
    }
    
    private struct InferredSourceInfo: Sendable {
        let source: String
        let sourceType: String
        let sourceUrl: String
        let skillPath: String?
    }
    
    private func inferSourceInfo(forSkillAt skillFolderURL: URL, slug: String) -> InferredSourceInfo {
        // Clawdhub skills store metadata under `.clawdhub/origin.json`
        let clawdhubOriginURL = skillFolderURL
            .appendingPathComponent(".clawdhub")
            .appendingPathComponent("origin.json")
        
        if STFile(clawdhubOriginURL).isExists,
           let data = try? STFile(clawdhubOriginURL).data(),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           (json["source"] as? String) == "clawdhub" {
            return InferredSourceInfo(
                source: "clawdhub/\(slug)",
                sourceType: "clawdhub",
                sourceUrl: "https://clawdhub.com/skills/\(slug)",
                skillPath: nil
            )
        }
        
        // Fallback: treat as local.
        return InferredSourceInfo(
            source: "local/\(slug)",
            sourceType: "local",
            sourceUrl: skillFolderURL.standardizedFileURL.absoluteString,
            skillPath: nil
        )
    }
    
    public func addOrUpdateSkill(
        slug: String,
        source: String,
        sourceType: String,
        sourceUrl: String,
        skillPath: String? = nil,
        skillFolderHash: String? = nil,
        version: String? = nil,
        displayName: String? = nil
    ) async throws {
        var lockFile = try await readLockFile()
        let now = Date()
        
        let existingEntry = lockFile.skills[slug]
        
        let entry = SkillLockEntry(
            source: source,
            sourceType: sourceType,
            sourceUrl: sourceUrl,
            skillPath: skillPath,
            skillFolderHash: skillFolderHash,
            installedAt: existingEntry?.installedAt ?? now,
            updatedAt: now,
            version: version,
            displayName: displayName
        )
        
        lockFile.skills[slug] = entry
        try await writeLockFile(lockFile)
    }
    
    public func removeSkill(slug: String) async throws {
        var lockFile = try await readLockFile()
        lockFile.skills.removeValue(forKey: slug)
        try await writeLockFile(lockFile)
    }
    
    public func getSkillEntry(slug: String) async throws -> SkillLockEntry? {
        let lockFile = try await readLockFile()
        return lockFile.skills[slug]
    }
    
    public func getAllSkills() async throws -> [String: SkillLockEntry] {
        let lockFile = try await readLockFile()
        return lockFile.skills
    }
    
    public func isSkillTracked(slug: String) async throws -> Bool {
        let lockFile = try await readLockFile()
        return lockFile.skills[slug] != nil
    }
    
    public func getSkillsBySource() async throws -> [String: [String: SkillLockEntry]] {
        let lockFile = try await readLockFile()
        var bySource: [String: [String: SkillLockEntry]] = [:]
        
        for (slug, entry) in lockFile.skills {
            let source = entry.source
            if bySource[source] == nil {
                bySource[source] = [:]
            }
            bySource[source]?[slug] = entry
        }
        
        return bySource
    }
    
    public func updateSkillHash(slug: String, hash: String?) async throws {
        var lockFile = try await readLockFile()
        
        guard let entry = lockFile.skills[slug] else {
            return
        }
        
        let updatedEntry = SkillLockEntry(
            source: entry.source,
            sourceType: entry.sourceType,
            sourceUrl: entry.sourceUrl,
            skillPath: entry.skillPath,
            skillFolderHash: hash,
            installedAt: entry.installedAt,
            updatedAt: Date(),
            version: entry.version,
            displayName: entry.displayName
        )
        
        lockFile.skills[slug] = updatedEntry
        try await writeLockFile(lockFile)
    }
    
    public func saveLastSelectedProviders(_ providers: [String]) async throws {
        var lockFile = try await readLockFile()
        lockFile.lastSelectedProviders = providers
        try await writeLockFile(lockFile)
    }
    
    public func getLastSelectedProviders() async throws -> [String]? {
        let lockFile = try await readLockFile()
        return lockFile.lastSelectedProviders
    }
    
    public func dismissPrompt(_ promptKey: String) async throws {
        var lockFile = try await readLockFile()
        if lockFile.dismissedPrompts == nil {
            lockFile.dismissedPrompts = [:]
        }
        lockFile.dismissedPrompts?[promptKey] = true
        try await writeLockFile(lockFile)
    }
    
    public func isPromptDismissed(_ promptKey: String) async throws -> Bool {
        let lockFile = try await readLockFile()
        return lockFile.dismissedPrompts?[promptKey] == true
    }
}

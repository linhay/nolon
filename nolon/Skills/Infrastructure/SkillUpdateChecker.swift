import Foundation

public actor SkillUpdateChecker {
    private let lockFileManager: SkillLockFileManager
    private let gitHubAPI: GitHubAPIService
    private let clawdhubRepository: ClawdhubRepository
    
    public init() {
        self.lockFileManager = SkillLockFileManager()
        self.gitHubAPI = GitHubAPIService()
        self.clawdhubRepository = ClawdhubRepository()
    }
    
    public init(
        lockFileManager: SkillLockFileManager,
        gitHubAPI: GitHubAPIService,
        clawdhubRepository: ClawdhubRepository
    ) {
        self.lockFileManager = lockFileManager
        self.gitHubAPI = gitHubAPI
        self.clawdhubRepository = clawdhubRepository
    }
    
    public func checkForUpdates() async -> [SkillUpdateInfo] {
        var updates: [SkillUpdateInfo] = []
        
        let skills = await (try? lockFileManager.getAllSkills()) ?? [:]
        
        await withTaskGroup(of: SkillUpdateInfo?.self) { group in
            for (slug, entry) in skills {
                group.addTask {
                    await self.checkSkillForUpdate(slug: slug, entry: entry)
                }
            }
            
            for await updateInfo in group {
                if let info = updateInfo {
                    updates.append(info)
                }
            }
        }
        
        return updates.sorted { $0.skillName < $1.skillName }
    }
    
    private func checkSkillForUpdate(slug: String, entry: SkillLockEntry) async -> SkillUpdateInfo? {
        switch entry.sourceType {
        case "clawdhub":
            return await checkClawdhubSkill(slug: slug, entry: entry)
        case "github", "gitlab":
            return await checkGitSkill(slug: slug, entry: entry)
        default:
            return nil
        }
    }
    
    private func checkClawdhubSkill(slug: String, entry: SkillLockEntry) async -> SkillUpdateInfo? {
        do {
            let remoteSkills = try await clawdhubRepository.fetchSkills(query: slug, limit: 10)
            
            guard let remoteSkill = remoteSkills.first(where: { $0.slug == slug }) else {
                return nil
            }
            
            let hasUpdate = remoteSkill.latestVersion?.version != entry.version
            
            return SkillUpdateInfo(
                id: slug,
                skillName: entry.displayName ?? slug,
                currentVersion: entry.version,
                latestVersion: remoteSkill.latestVersion?.version,
                hasUpdate: hasUpdate,
                currentHash: entry.skillFolderHash,
                latestHash: nil,
                updateSource: .clawdhub
            )
        } catch {
            return nil
        }
    }
    
    private func checkGitSkill(slug: String, entry: SkillLockEntry) async -> SkillUpdateInfo? {
        guard let ownerRepo = await gitHubAPI.extractOwnerRepo(from: entry.sourceUrl) else {
            return nil
        }
        
        do {
            let currentHash = entry.skillFolderHash
            let latestHash = try await gitHubAPI.fetchSkillFolderHash(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo,
                skillPath: entry.skillPath
            )
            
            let canDetermineStatus = currentHash != nil && latestHash != nil
            let hasUpdate = canDetermineStatus && currentHash != latestHash
            
            return SkillUpdateInfo(
                id: slug,
                skillName: entry.displayName ?? slug,
                currentVersion: entry.version,
                latestVersion: nil,
                hasUpdate: hasUpdate,
                currentHash: currentHash,
                latestHash: latestHash,
                updateSource: .github
            )
        } catch {
            return nil
        }
    }
    
    public func getUpdatableSkillsCount() async -> Int {
        let updates = await checkForUpdates()
        return updates.filter { $0.hasUpdate }.count
    }
}

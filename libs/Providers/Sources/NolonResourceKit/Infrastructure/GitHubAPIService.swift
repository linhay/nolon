import Foundation

/// GitHub API client for fetching repository metadata
/// Used to get tree SHA for update checking
public actor GitHubAPIService {
    
    private let baseURL = "https://api.github.com"
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    // MARK: - Tree SHA
    
    /// Fetch the tree SHA for a skill folder using GitHub's Trees API
    /// This makes ONE API call to get the entire repo tree, then extracts the SHA
    /// for the specific skill folder
    ///
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - skillPath: Path to skill folder (e.g., "skills/react-best-practices" or nil for root)
    /// - Returns: The tree SHA for the skill folder, or nil if not found
    public func fetchSkillFolderHash(
        owner: String,
        repo: String,
        skillPath: String?
    ) async throws -> String? {
        let branches = ["main", "master"]
        
        for branch in branches {
            if let hash = try? await fetchTreeSHA(
                owner: owner,
                repo: repo,
                skillPath: skillPath,
                branch: branch
            ) {
                return hash
            }
        }
        
        return nil
    }
    
    private func fetchTreeSHA(
        owner: String,
        repo: String,
        skillPath: String?,
        branch: String
    ) async throws -> String? {
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("nolon-app", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }
        
        let treeResponse = try jsonDecoder.decode(GitTreeResponse.self, from: data)
        
        // If skillPath is empty/nil, return the root tree SHA
        guard let skillPath = skillPath, !skillPath.isEmpty else {
            return treeResponse.sha
        }
        
        var normalizedPath = skillPath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if normalizedPath.hasSuffix("/SKILL.md") {
            normalizedPath = String(normalizedPath.dropLast(9))
        } else if normalizedPath.hasSuffix("SKILL.md") {
            normalizedPath = String(normalizedPath.dropLast(8))
        }
        
        if normalizedPath.hasSuffix("/") {
            normalizedPath = String(normalizedPath.dropLast())
        }
        
        let folderEntry = treeResponse.tree.first { entry in
            entry.type == "tree" && entry.path == normalizedPath
        }
        
        return folderEntry?.sha
    }
    
    // MARK: - URL Parsing
    
    /// Extract owner and repo from GitHub URL
    /// Supports: https://github.com/owner/repo or git@github.com:owner/repo.git
    public func extractOwnerRepo(from url: String) -> (owner: String, repo: String)? {
        let cleaned = url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // SSH format: git@github.com:owner/repo
        if cleaned.hasPrefix("git@github.com:") {
            let path = cleaned.dropFirst(15)
            let components = path.split(separator: "/")
            if components.count >= 2 {
                return (String(components[0]), String(components[1]))
            }
        }
        
        // HTTPS format: https://github.com/owner/repo
        if let urlObj = URL(string: cleaned),
           urlObj.host?.contains("github.com") == true {
            let pathComponents = urlObj.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count >= 2 {
                return (String(pathComponents[0]), String(pathComponents[1]))
            }
        }
        
        return nil
    }
    
    /// Extract skill subpath from a full GitHub URL
    /// e.g., "https://github.com/owner/repo/tree/main/skills/my-skill" -> "skills/my-skill"
    public func extractSkillPath(from url: String) -> String? {
        guard let urlObj = URL(string: url) else {
            return nil
        }
        
        let path = urlObj.path
        // Look for patterns like /tree/{branch}/{path} or /blob/{branch}/{path}
        let patterns = ["/tree/", "/blob/"]
        
        for pattern in patterns {
            if let range = path.range(of: pattern) {
                let afterPattern = path[range.upperBound...]
                // Skip the branch name (first component)
                let components = afterPattern.split(separator: "/")
                if components.count > 1 {
                    let pathComponents = components.dropFirst()
                    return pathComponents.joined(separator: "/")
                }
            }
        }
        
        return nil
    }
}

// MARK: - GitHub API Response Models

@preconcurrency
struct GitTreeResponse: Decodable, Sendable {
    let sha: String
    let tree: [GitTreeEntry]

    enum CodingKeys: String, CodingKey {
        case sha
        case tree
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sha = try container.decode(String.self, forKey: .sha)
        self.tree = try container.decode([GitTreeEntry].self, forKey: .tree)
    }
}

@preconcurrency
struct GitTreeEntry: Decodable, Sendable {
    let path: String
    let type: String
    let sha: String

    enum CodingKeys: String, CodingKey {
        case path
        case type
        case sha
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.type = try container.decode(String.self, forKey: .type)
        self.sha = try container.decode(String.self, forKey: .sha)
    }
}

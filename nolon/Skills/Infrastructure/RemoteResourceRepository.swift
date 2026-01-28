import Foundation

// MARK: - Repository Protocol

/// Protocol for remote resource repositories
public protocol RemoteResourceRepository: Sendable {
    /// Unique identifier for this repository
    var id: String { get }
    
    /// Display name
    var name: String { get }
    
    /// Supported resource types
    var supportedTypes: Set<RemoteContentType> { get }
    
    // MARK: - Fetch Resources
    
    /// Fetch skills from repository
    func fetchSkills(query: String?, limit: Int) async throws -> [RemoteSkill]
    
    /// Fetch workflows from repository
    func fetchWorkflows(query: String?, limit: Int) async throws -> [RemoteWorkflow]
    
    /// Fetch MCPs from repository
    func fetchMCPs(query: String?, limit: Int) async throws -> [RemoteMCP]
    
    // MARK: - Download Resources
    
    /// Download skill to temporary location
    /// - Returns: URL to downloaded file/directory
    func downloadSkill(slug: String) async throws -> URL
    
    /// Download workflow to temporary location
    /// - Returns: URL to downloaded file
    func downloadWorkflow(slug: String) async throws -> URL
    
    /// Download MCP configuration to temporary location
    /// - Returns: URL to downloaded configuration file
    func downloadMCP(slug: String) async throws -> URL
    
    // MARK: - Repository Sync
    
    /// Synchronize repository (for Git repositories)
    func sync() async throws -> Bool
    
    /// Last synchronization date
    var lastSyncDate: Date? { get }
}

// MARK: - Default Implementations

extension RemoteResourceRepository {
    /// Default implementation throws unsupported error
    public func fetchWorkflows(query: String?, limit: Int) async throws -> [RemoteWorkflow] {
        throw RepositoryError.unsupportedType(.workflow)
    }
    
    /// Default implementation throws unsupported error
    public func fetchMCPs(query: String?, limit: Int) async throws -> [RemoteMCP] {
        throw RepositoryError.unsupportedType(.mcp)
    }
    
    /// Default implementation throws unsupported error
    public func downloadWorkflow(slug: String) async throws -> URL {
        throw RepositoryError.unsupportedType(.workflow)
    }
    
    /// Default implementation throws unsupported error
    public func downloadMCP(slug: String) async throws -> URL {
        throw RepositoryError.unsupportedType(.mcp)
    }
    
    /// Default implementation - no sync needed
    public func sync() async throws -> Bool {
        return true
    }
    
    /// Default implementation - no sync date
    public var lastSyncDate: Date? { nil }
}

// MARK: - Repository Errors

public enum RepositoryError: LocalizedError {
    case unsupportedType(RemoteContentType)
    case invalidURL
    case networkError(Error)
    case resourceNotFound(String)
    case downloadFailed(String)
    case extractionFailed
    case invalidPackage
    case gitOperationFailed(String)
    case fileOperationFailed(String)
    case parsingFailed(String)
    case notImplemented
    case accessDenied
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return NSLocalizedString(
                "error.repository.unsupported_type",
                comment: "Resource type not supported: \(type.rawValue)"
            )
        case .invalidURL:
            return NSLocalizedString("error.repository.invalid_url", comment: "Invalid URL")
        case .networkError(let error):
            return String(
                format: NSLocalizedString(
                    "error.repository.network",
                    comment: "Network error: %@"
                ),
                error.localizedDescription
            )
        case .resourceNotFound(let id):
            return String(
                format: NSLocalizedString(
                    "error.repository.resource_not_found",
                    comment: "Resource not found: %@"
                ),
                id
            )
        case .downloadFailed(let reason):
            return String(
                format: NSLocalizedString(
                    "error.repository.download_failed",
                    comment: "Download failed: %@"
                ),
                reason
            )
        case .extractionFailed:
            return NSLocalizedString(
                "error.repository.extraction_failed",
                comment: "Failed to extract package"
            )
        case .invalidPackage:
            return NSLocalizedString(
                "error.repository.invalid_package",
                comment: "Invalid package structure"
            )
        case .gitOperationFailed(let operation):
            return String(
                format: NSLocalizedString(
                    "error.repository.git_failed",
                    comment: "Git operation failed: %@"
                ),
                operation
            )
        case .fileOperationFailed(let operation):
            return String(
                format: NSLocalizedString(
                    "error.repository.file_failed",
                    comment: "File operation failed: %@"
                ),
                operation
            )
        case .parsingFailed(let reason):
            return String(
                format: NSLocalizedString(
                    "error.repository.parsing_failed",
                    comment: "Parsing failed: %@"
                ),
                reason
            )
        case .notImplemented:
            return NSLocalizedString(
                "error.repository.not_implemented",
                comment: "Not implemented"
            )
        case .accessDenied:
            return NSLocalizedString(
                "error.repository.access_denied",
                comment: "Access denied"
            )
        case .invalidConfiguration:
            return NSLocalizedString(
                "error.repository.invalid_configuration",
                comment: "Invalid configuration"
            )
        }
    }
}

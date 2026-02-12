import Foundation

public nonisolated enum CodexTerminalApp: String, Codable, CaseIterable, Sendable, Identifiable {
    case terminal = "com.apple.Terminal"
    case iTerm = "com.googlecode.iterm2"
    case warp = "dev.warp.Warp"
    case warpStable = "dev.warp.Warp-Stable"
    case warpPreview = "dev.warp.Warp-Preview"
    case ghostty = "com.mitchellh.ghostty"

    public var id: String { rawValue }
    public var bundleIdentifier: String { rawValue }
    public var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iTerm: return "iTerm"
        case .warp: return "Warp"
        case .warpStable: return "Warp"
        case .warpPreview: return "Warp Preview"
        case .ghostty: return "Ghostty"
        }
    }

    public static func resolveTarget(
        explicit: CodexTerminalApp?,
        preferredBundleID: String?,
        available: [CodexTerminalApp]
    ) -> CodexTerminalApp? {
        if let explicit, available.contains(explicit) {
            return explicit
        }
        if let preferredBundleID,
           let preferred = available.first(where: { $0.bundleIdentifier == preferredBundleID }) {
            return preferred
        }
        return available.first
    }
}

public nonisolated enum CodexBinaryUpdateState: String, Codable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable
    case checkFailed
}

public nonisolated struct ManagedCodexVersion: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public var displayName: String
    public let detectedVersion: String
    public let binaryRelativePath: String
    public let sha256: String
    public let source: String
    public let sourceURL: String?
    public let importedAt: Date
    public let notes: String?

    public init(
        id: String,
        displayName: String,
        detectedVersion: String,
        binaryRelativePath: String,
        sha256: String,
        source: String,
        sourceURL: String?,
        importedAt: Date,
        notes: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.detectedVersion = detectedVersion
        self.binaryRelativePath = binaryRelativePath
        self.sha256 = sha256
        self.source = source
        self.sourceURL = sourceURL
        self.importedAt = importedAt
        self.notes = notes
    }
}

public nonisolated struct CodexBinaryManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var selectedVersionId: String?
    public var syncModelOnSwitch: Bool
    public var preferredModel: String?
    public var preferredTerminalBundleID: String?
    public var launchEnvironment: [String: String]
    public var versions: [ManagedCodexVersion]
    public var lastUpdateCheckAt: Date?
    public var lastSeenRemoteVersion: String?
    public var lastSeenRemoteTag: String?
    public var lastSeenRemoteAssetURL: String?
    public var includeBetaVersions: Bool
    public var updateState: CodexBinaryUpdateState

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case selectedVersionId
        case syncModelOnSwitch
        case preferredModel
        case preferredTerminalBundleID
        case launchEnvironment
        case versions
        case lastUpdateCheckAt
        case lastSeenRemoteVersion
        case lastSeenRemoteTag
        case lastSeenRemoteAssetURL
        case includeBetaVersions
        case updateState
    }

    public init(
        schemaVersion: Int = 1,
        selectedVersionId: String? = nil,
        syncModelOnSwitch: Bool = false,
        preferredModel: String? = nil,
        preferredTerminalBundleID: String? = nil,
        launchEnvironment: [String: String] = [:],
        versions: [ManagedCodexVersion] = [],
        lastUpdateCheckAt: Date? = nil,
        lastSeenRemoteVersion: String? = nil,
        lastSeenRemoteTag: String? = nil,
        lastSeenRemoteAssetURL: String? = nil,
        includeBetaVersions: Bool = false,
        updateState: CodexBinaryUpdateState = .idle
    ) {
        self.schemaVersion = schemaVersion
        self.selectedVersionId = selectedVersionId
        self.syncModelOnSwitch = syncModelOnSwitch
        self.preferredModel = preferredModel
        self.preferredTerminalBundleID = preferredTerminalBundleID
        self.launchEnvironment = launchEnvironment
        self.versions = versions
        self.lastUpdateCheckAt = lastUpdateCheckAt
        self.lastSeenRemoteVersion = lastSeenRemoteVersion
        self.lastSeenRemoteTag = lastSeenRemoteTag
        self.lastSeenRemoteAssetURL = lastSeenRemoteAssetURL
        self.includeBetaVersions = includeBetaVersions
        self.updateState = updateState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.selectedVersionId = try container.decodeIfPresent(String.self, forKey: .selectedVersionId)
        self.syncModelOnSwitch = try container.decodeIfPresent(Bool.self, forKey: .syncModelOnSwitch) ?? false
        self.preferredModel = try container.decodeIfPresent(String.self, forKey: .preferredModel)
        self.preferredTerminalBundleID = try container.decodeIfPresent(String.self, forKey: .preferredTerminalBundleID)
        self.launchEnvironment = try container.decodeIfPresent([String: String].self, forKey: .launchEnvironment) ?? [:]
        self.versions = try container.decodeIfPresent([ManagedCodexVersion].self, forKey: .versions) ?? []
        self.lastUpdateCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckAt)
        self.lastSeenRemoteVersion = try container.decodeIfPresent(String.self, forKey: .lastSeenRemoteVersion)
        self.lastSeenRemoteTag = try container.decodeIfPresent(String.self, forKey: .lastSeenRemoteTag)
        self.lastSeenRemoteAssetURL = try container.decodeIfPresent(String.self, forKey: .lastSeenRemoteAssetURL)
        self.includeBetaVersions = try container.decodeIfPresent(Bool.self, forKey: .includeBetaVersions) ?? false
        self.updateState = try container.decodeIfPresent(CodexBinaryUpdateState.self, forKey: .updateState) ?? .idle
    }

    public static let `default` = CodexBinaryManifest()
}

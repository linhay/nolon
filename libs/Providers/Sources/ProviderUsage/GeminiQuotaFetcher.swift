import Foundation
import SKProcessRunner

public struct GeminiQuotaBucket: Sendable, Equatable {
    public let modelID: String
    public let remainingFraction: Double
    public let resetTime: Date?

    public init(modelID: String, remainingFraction: Double, resetTime: Date?) {
        self.modelID = modelID
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
    }
}

public struct GeminiQuotaSnapshot: Sendable, Equatable {
    public let buckets: [GeminiQuotaBucket]
    public let pro: GeminiQuotaBucket?
    public let flash: GeminiQuotaBucket?
    public let fetchedAt: Date

    public init(buckets: [GeminiQuotaBucket], pro: GeminiQuotaBucket?, flash: GeminiQuotaBucket?, fetchedAt: Date) {
        self.buckets = buckets
        self.pro = pro
        self.flash = flash
        self.fetchedAt = fetchedAt
    }
}

public enum GeminiQuotaFetchError: LocalizedError, Sendable, Equatable {
    case unsupportedAuthMethod(GeminiAuthMethod)
    case binaryNotFound(String)
    case corePackageNotFound(String)
    case executionFailed(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedAuthMethod(method):
            return "Gemini quota fetch is not supported for auth method: \(method.rawValue)"
        case let .binaryNotFound(binary):
            return "Missing CLI dependency '\(binary)'."
        case let .corePackageNotFound(path):
            return "Gemini CLI core package not found at: \(path)"
        case let .executionFailed(message):
            return "Failed to fetch Gemini quota: \(message)"
        case let .invalidResponse(message):
            return "Invalid Gemini quota response: \(message)"
        }
    }
}

public struct GeminiQuotaFetcher: Sendable {
    typealias ResolveExecutable = @Sendable (_ binary: String, _ environment: [String: String]) throws -> URL
    typealias RunNodeScript = @Sendable (_ nodeExecutableURL: URL, _ script: String, _ environment: [String: String]) async throws -> String
    typealias FileExists = @Sendable (_ path: String) -> Bool

    private let resolveExecutable: ResolveExecutable
    private let runNodeScript: RunNodeScript
    private let fileExists: FileExists
    private let now: @Sendable () -> Date

    public init() {
        self.resolveExecutable = { binary, environment in
            try GeminiLoginRunner.resolveExecutableURL(binary: binary, environment: environment)
        }
        self.runNodeScript = Self.runNodeScript
        self.fileExists = { FileManager.default.fileExists(atPath: $0) }
        self.now = Date.init
    }

    init(
        resolveExecutable: @escaping ResolveExecutable,
        runNodeScript: @escaping RunNodeScript,
        fileExists: @escaping FileExists = { FileManager.default.fileExists(atPath: $0) },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.resolveExecutable = resolveExecutable
        self.runNodeScript = runNodeScript
        self.fileExists = fileExists
        self.now = now
    }

    public func fetch(
        account: GeminiAuthAccount,
        runtimeHomeURL: URL,
        environment: [String: String]
    ) async throws -> GeminiQuotaSnapshot? {
        guard account.method == .oauthPersonal else {
            return nil
        }

        let geminiExecutableURL = try resolveExecutable("gemini", environment)
        let nodeExecutableURL = try resolveExecutable("node", environment)
        let coreIndexURL = try deriveCoreIndexURL(from: geminiExecutableURL)

        var processEnvironment = environment
        processEnvironment["PATH"] = processEnvironment["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        processEnvironment["GEMINI_CLI_HOME"] = runtimeHomeURL.path
        processEnvironment["GEMINI_FORCE_FILE_STORAGE"] = "true"
        processEnvironment["GOOGLE_GENAI_USE_GCA"] = "true"
        processEnvironment["NOLON_GEMINI_CORE_INDEX"] = coreIndexURL.path
        processEnvironment["NOLON_GEMINI_AUTH_TYPE"] = account.method.rawValue
        processEnvironment["NOLON_GEMINI_CWD"] = environment["PWD"] ?? FileManager.default.currentDirectoryPath

        let output = try await runNodeScript(nodeExecutableURL, Self.nodeScript, processEnvironment)
        return try parseSnapshot(from: output)
    }

    private func deriveCoreIndexURL(from geminiExecutableURL: URL) throws -> URL {
        let packageRoot = geminiExecutableURL
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let coreIndexURL = packageRoot
            .appendingPathComponent("node_modules", isDirectory: true)
            .appendingPathComponent("@google", isDirectory: true)
            .appendingPathComponent("gemini-cli-core", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.js", isDirectory: false)
        guard fileExists(coreIndexURL.path) else {
            throw GeminiQuotaFetchError.corePackageNotFound(coreIndexURL.path)
        }
        return coreIndexURL
    }

    private func parseSnapshot(from output: String) throws -> GeminiQuotaSnapshot {
        let jsonText = try extractJSONPayload(from: output)
        let data = Data(jsonText.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: QuotaResponse
        do {
            payload = try decoder.decode(QuotaResponse.self, from: data)
        } catch {
            throw GeminiQuotaFetchError.invalidResponse(error.localizedDescription)
        }

        let buckets = payload.quota.buckets ?? []
        let allBuckets = buckets.map { $0.toSnapshotBucket() }
        let pro = selectBucket(from: buckets, preferredModelIDs: Self.proModelPreference, fallback: { bucket in
            let id = bucket.modelID.lowercased()
            return id.contains("pro") && !id.contains("_vertex")
        })
        let flash = selectBucket(from: buckets, preferredModelIDs: Self.flashModelPreference, fallback: { bucket in
            let id = bucket.modelID.lowercased()
            return id.contains("flash") && !id.contains("lite") && !id.contains("_vertex")
        })

        return GeminiQuotaSnapshot(
            buckets: allBuckets,
            pro: pro,
            flash: flash,
            fetchedAt: now()
        )
    }

    private func extractJSONPayload(from output: String) throws -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeminiQuotaFetchError.invalidResponse("empty stdout")
        }
        if trimmed.first == "{", trimmed.last == "}" {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            throw GeminiQuotaFetchError.invalidResponse("missing JSON object")
        }

        let candidate = String(trimmed[start...end])
        guard candidate.first == "{", candidate.last == "}" else {
            throw GeminiQuotaFetchError.invalidResponse("missing JSON object")
        }
        return candidate
    }

    private func selectBucket(
        from buckets: [QuotaBucketPayload],
        preferredModelIDs: [String],
        fallback: (QuotaBucketPayload) -> Bool
    ) -> GeminiQuotaBucket? {
        for modelID in preferredModelIDs {
            if let bucket = buckets.first(where: { $0.modelID == modelID }) {
                return bucket.toSnapshotBucket()
            }
        }
        return buckets.first(where: fallback)?.toSnapshotBucket()
    }

    private static func runNodeScript(
        nodeExecutableURL: URL,
        script: String,
        environment: [String: String]
    ) async throws -> String {
        var payload = SKProcessPayload.executableURL(nodeExecutableURL)
        payload.arguments = ["--input-type=module", "-e", script]
        payload.environment = SKProcessEnvironment(environment)
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 20_000

        do {
            let result = try await SKProcessRunner.run(payload)
            guard result.exitCode == 0 else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw GeminiQuotaFetchError.executionFailed(message.isEmpty ? "node exited with code \(result.exitCode)" : message)
            }
            let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return stdout
        } catch let error as GeminiQuotaFetchError {
            throw error
        } catch {
            throw GeminiQuotaFetchError.executionFailed(error.localizedDescription)
        }
    }

    private static let proModelPreference = [
        "gemini-3.1-pro-preview",
        "gemini-3-pro-preview",
        "gemini-2.5-pro",
    ]

    private static let flashModelPreference = [
        "gemini-3-flash-preview",
        "gemini-2.5-flash",
        "gemini-2.0-flash",
    ]

    private static let nodeScript = #"""
import { pathToFileURL } from 'node:url';

const coreIndex = process.env.NOLON_GEMINI_CORE_INDEX;
const authType = process.env.NOLON_GEMINI_AUTH_TYPE;
const cwd = process.env.NOLON_GEMINI_CWD || process.cwd();

if (!coreIndex) {
  throw new Error('Missing NOLON_GEMINI_CORE_INDEX');
}
if (!authType) {
  throw new Error('Missing NOLON_GEMINI_AUTH_TYPE');
}

const core = await import(pathToFileURL(coreIndex).href);
const { Config, getOauthClient, setupUser, CodeAssistServer } = core;

const config = new Config({
  sessionId: 'nolon-gemini-quota',
  debugMode: false,
  targetDir: cwd,
  cwd,
  model: 'gemini-2.5-pro',
});

const client = await getOauthClient(authType, config);
const user = await setupUser(client, undefined, {});
const server = new CodeAssistServer(
  client,
  user.projectId,
  {},
  'nolon-gemini-quota',
  user.userTier,
  user.userTierName,
  user.paidTier,
  config,
);
const quota = await server.retrieveUserQuota({ project: user.projectId });
console.log(JSON.stringify({ projectId: user.projectId, quota }));
"""#
}

private struct QuotaResponse: Decodable {
    let projectID: String?
    let quota: QuotaPayload

    enum CodingKeys: String, CodingKey {
        case projectID = "projectId"
        case quota
    }
}

private struct QuotaPayload: Decodable {
    let buckets: [QuotaBucketPayload]?
}

private struct QuotaBucketPayload: Decodable {
    let modelID: String
    let remainingFraction: Double
    let resetTime: Date?

    enum CodingKeys: String, CodingKey {
        case modelID = "modelId"
        case remainingFraction
        case resetTime
    }

    func toSnapshotBucket() -> GeminiQuotaBucket {
        GeminiQuotaBucket(
            modelID: modelID,
            remainingFraction: remainingFraction,
            resetTime: resetTime
        )
    }
}

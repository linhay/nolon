import Foundation
import STJSON
import SKProcessRunner
import STFilePath

enum CodexAuthManagerSupport {
    struct ImportCandidate {
        let candidateURL: URL
        let sourceGroupID: String
        let sourceGroupLabel: String
        let data: Data
    }
    private static let oauthTokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let oauthClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let oidcDiscoveryURL = URL(string: "https://auth.openai.com/.well-known/openid-configuration")!
    private static let fallbackUserInfoURL = URL(string: "https://auth.openai.com/userinfo")!

    static func refreshOAuthTokens(refreshToken: String) async throws -> CodexAuthManager.RefreshedOAuthTokens {
        let trimmed = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.TokenRefresh",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing refresh token"]
            )
        }

        var request = URLRequest(url: oauthTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let form = [
            "client_id": oauthClientID,
            "grant_type": "refresh_token",
            "refresh_token": trimmed,
            "scope": "openid profile email",
        ]
        request.httpBody = form
            .map { "\($0.key)=\(($0.value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "CodexAuthManager.TokenRefresh",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected refresh token response"]
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "CodexAuthManager.TokenRefresh",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body.isEmpty ? "Token refresh failed with status \(http.statusCode)" : body]
            )
        }

        guard let json = try? JSON(data: data) else {
            throw NSError(
                domain: "CodexAuthManager.TokenRefresh",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid token refresh response JSON"]
            )
        }

        let idToken = json["id_token"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let accessToken = json["access_token"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !idToken.isEmpty, !accessToken.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.TokenRefresh",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Token refresh response missing id_token or access_token"]
            )
        }

        let refreshedToken = json["refresh_token"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodexAuthManager.RefreshedOAuthTokens(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshedToken?.isEmpty == true ? nil : refreshedToken,
            expiresIn: json["expires_in"].int
        )
    }

    static func fetchOAuthAccountInfo(accessToken: String) async throws -> CodexAuthManager.FetchedOAuthAccountInfo? {
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var candidateURLs: [URL] = []
        if let discovered = try? await fetchOIDCUserInfoEndpoint() {
            candidateURLs.append(discovered)
        }
        if !candidateURLs.contains(fallbackUserInfoURL) {
            candidateURLs.append(fallbackUserInfoURL)
        }

        for url in candidateURLs {
            if let info = try? await fetchOAuthAccountInfo(from: url, accessToken: trimmed) {
                if info.email != nil || info.accountID != nil || info.planType != nil {
                    return info
                }
            }
        }
        return nil
    }

    static func runDitto(arguments: [String]) throws {
        var payload = SKProcessPayload.executableURL(STPath("/usr/bin/ditto").url)
        payload.arguments = arguments
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 120_000
        let result = try SKProcessRunner.runSync(payload)

        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexAuthManager.Ditto",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "ditto failed" : message]
            )
        }
    }

    static func importCandidates(for url: URL) throws -> [ImportCandidate] {
        if url.pathExtension.lowercased() == "zip" {
            return try importCandidatesFromArchive(url)
        }
        let data = try Data(contentsOf: url)
        return expandJSONArrayCandidateIfNeeded(
            candidateURL: url,
            sourceGroupID: url.standardizedFileURL.path,
            sourceGroupLabel: url.lastPathComponent,
            data: data
        )
    }

    static func decodeJSONObject(from data: Data, decoder: JSONDecoder) -> [String: Any]? {
        guard let root = try? decoder.decode([String: AnyDecodable].self, from: data) else { return nil }
        return root.mapValues { $0.value }
    }

    static func encodeJSONObject(_ object: [String: Any], encoder: JSONEncoder) throws -> Data {
        let encodable = object.mapValues { AnyEncodable($0) }
        return try encoder.encode(encodable)
    }

    static func getString(_ dict: [String: Any], path: [String]) -> String? {
        guard let last = path.last else { return nil }
        let parent = getDictionary(dict, path: Array(path.dropLast()))
        return parent?[last] as? String
    }

    static func getDictionary(_ dict: [String: Any], path: [String]) -> [String: Any]? {
        guard !path.isEmpty else { return dict }
        var current: Any = dict
        for key in path {
            guard let next = (current as? [String: Any])?[key] else { return nil }
            current = next
        }
        return current as? [String: Any]
    }

    static func setValue(_ value: Any, path: [String], dict: inout [String: Any]) {
        guard let key = path.first else { return }
        if path.count == 1 {
            dict[key] = value
            return
        }
        var child = dict[key] as? [String: Any] ?? [:]
        setValue(value, path: Array(path.dropFirst()), dict: &child)
        dict[key] = child
    }

    static func removeValue(path: [String], dict: inout [String: Any]) {
        guard let key = path.first else { return }
        if path.count == 1 {
            dict.removeValue(forKey: key)
            return
        }
        guard var child = dict[key] as? [String: Any] else { return }
        removeValue(path: Array(path.dropFirst()), dict: &child)
        if child.isEmpty {
            dict.removeValue(forKey: key)
        } else {
            dict[key] = child
        }
    }

    static func encodeJSONObjectObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        return object
    }

    static func firstNonEmptyString(in json: JSON?, paths: [[String]]) -> String? {
        for path in paths {
            var current = json ?? JSON.null
            for key in path {
                current = current[key]
            }
            if let value = current.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty
            {
                return value
            }
        }
        return nil
    }

    static func firstNonEmptyString(in object: [String: Any], keys: [String]) -> String? {
        for keyPath in keys {
            let segments = keyPath.split(separator: ".").map(String.init)
            guard let last = segments.last else { continue }
            let parent = getDictionary(object, path: Array(segments.dropLast()))
            if let value = parent?[last] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func fetchOIDCUserInfoEndpoint() async throws -> URL {
        var request = URLRequest(url: oidcDiscoveryURL, timeoutInterval: 6)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "CodexAuthManager.UserInfo", code: 1)
        }
        guard let json = try? JSON(data: data),
              let endpoint = json["userinfo_endpoint"].string?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: endpoint)
        else {
            throw NSError(domain: "CodexAuthManager.UserInfo", code: 2)
        }
        return url
    }

    private static func fetchOAuthAccountInfo(from endpoint: URL, accessToken: String) async throws -> CodexAuthManager.FetchedOAuthAccountInfo {
        var request = URLRequest(url: endpoint, timeoutInterval: 6)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "CodexAuthManager.UserInfo", code: 3)
        }
        guard let json = try? JSON(data: data) else {
            throw NSError(domain: "CodexAuthManager.UserInfo", code: 4)
        }

        func first(in json: JSON, paths: [[String]]) -> String? {
            for path in paths {
                var current = json
                for key in path {
                    current = current[key]
                }
                if let value = current.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty
                {
                    return value
                }
            }
            return nil
        }

        let email = first(in: json, paths: [
            ["email"],
            ["https://api.openai.com/profile", "email"],
            ["profile", "email"],
        ])
        let accountID = first(in: json, paths: [
            ["https://api.openai.com/auth", "chatgpt_account_id"],
            ["chatgpt_account_id"],
            ["account_id"],
            ["sub"],
        ])
        let planType = first(in: json, paths: [
            ["https://api.openai.com/auth", "chatgpt_plan_type"],
            ["chatgpt_plan_type"],
            ["plan_type"],
            ["plan"],
        ])
        return CodexAuthManager.FetchedOAuthAccountInfo(email: email, accountID: accountID, planType: planType)
    }

    private static func importCandidatesFromArchive(_ archiveURL: URL) throws -> [ImportCandidate] {
        let fileManager = FileManager.default
        let extractionRoot = fileManager.temporaryDirectory.appendingPathComponent("codex-import-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: extractionRoot) }

        try runDitto(arguments: ["-x", "-k", archiveURL.path, extractionRoot.path])

        guard let enumerator = fileManager.enumerator(at: extractionRoot, includingPropertiesForKeys: nil) else {
            return []
        }

        let sourceGroupID = archiveURL.standardizedFileURL.path
        let sourceGroupLabel = archiveURL.lastPathComponent
        var candidates: [ImportCandidate] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "json" else { continue }
            let data = try Data(contentsOf: fileURL)
            candidates.append(
                contentsOf: expandJSONArrayCandidateIfNeeded(
                    candidateURL: fileURL,
                    sourceGroupID: sourceGroupID,
                    sourceGroupLabel: sourceGroupLabel,
                    data: data
                )
            )
        }
        return candidates.sorted { $0.candidateURL.lastPathComponent < $1.candidateURL.lastPathComponent }
    }

    private static func expandJSONArrayCandidateIfNeeded(
        candidateURL: URL,
        sourceGroupID: String,
        sourceGroupLabel: String,
        data: Data
    ) -> [ImportCandidate] {
        guard let json = try? JSON(data: data),
              let array = json.arrayObject
        else {
            return [
                ImportCandidate(
                    candidateURL: candidateURL,
                    sourceGroupID: sourceGroupID,
                    sourceGroupLabel: sourceGroupLabel,
                    data: data
                ),
            ]
        }

        let baseName = candidateURL.deletingPathExtension().lastPathComponent
        var expanded: [ImportCandidate] = []
        expanded.reserveCapacity(array.count)

        for (index, element) in array.enumerated() {
            guard let object = element as? [String: Any] else { continue }
            guard let elementData = try? JSONSerialization.data(withJSONObject: object) else { continue }
            let itemName = String(format: "%@-item-%02d.json", baseName, index + 1)
            let syntheticURL = candidateURL
                .deletingLastPathComponent()
                .appendingPathComponent(itemName)
            expanded.append(
                ImportCandidate(
                    candidateURL: syntheticURL,
                    sourceGroupID: sourceGroupID,
                    sourceGroupLabel: sourceGroupLabel,
                    data: elementData
                )
            )
        }

        return expanded.isEmpty
            ? [
                ImportCandidate(
                    candidateURL: candidateURL,
                    sourceGroupID: sourceGroupID,
                    sourceGroupLabel: sourceGroupLabel,
                    data: data
                ),
            ]
            : expanded
    }
}

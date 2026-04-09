import Foundation
import OSLog
import CryptoKit
import Darwin
import STFilePath
import ProviderCatalog
import STJSON
import ProvidersShared
import SQLite3

extension CodexAuthManager {
    public func validateImportAuthFiles(urls: [URL]) async -> [CodexImportValidationResult] {
        var results: [CodexImportValidationResult] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            do {
                let candidates = try importCandidates(for: url)
                guard !candidates.isEmpty else {
                    results.append(
                        CodexImportValidationResult(
                            fileURL: url,
                            sourceGroupID: url.standardizedFileURL.path,
                            sourceGroupLabel: url.lastPathComponent,
                            isValid: false,
                            reason: "No auth JSON files found in archive",
                            suggestedName: nil,
                            email: nil,
                            authJSONString: nil
                        )
                    )
                    continue
                }
                for (candidateURL, sourceGroupID, sourceGroupLabel, data) in candidates {
                    var normalizedData = Self.normalizeImportedAuthJSONDataIfNeeded(data) ?? data
                    let enrichment = await enrichImportedAuthDataIfNeeded(normalizedData)
                    normalizedData = enrichment.data
                    guard let raw = String(data: normalizedData, encoding: .utf8) else {
                        results.append(
                            CodexImportValidationResult(
                                fileURL: candidateURL,
                                sourceGroupID: sourceGroupID,
                                sourceGroupLabel: sourceGroupLabel,
                                isValid: false,
                                reason: "Invalid UTF-8",
                                suggestedName: nil,
                                email: nil,
                                authJSONString: nil
                            )
                        )
                        continue
                    }
                    if let json = try? JSON(data: normalizedData) {
                        let type = json["type"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let type, !type.isEmpty, type.lowercased() != "codex" {
                            results.append(
                                CodexImportValidationResult(
                                    fileURL: candidateURL,
                                    sourceGroupID: sourceGroupID,
                                    sourceGroupLabel: sourceGroupLabel,
                                    isValid: false,
                                    reason: "Unsupported auth type: \(type)",
                                    suggestedName: nil,
                                    email: nil,
                                    authJSONString: nil
                                )
                            )
                            continue
                        }
                        if case let .invalid(reason) = credentialIdentityValidationResult(from: json) {
                            results.append(
                                CodexImportValidationResult(
                                    fileURL: candidateURL,
                                    sourceGroupID: sourceGroupID,
                                    sourceGroupLabel: sourceGroupLabel,
                                    isValid: false,
                                    reason: reason,
                                    suggestedName: nil,
                                    email: nil,
                                    authJSONString: nil
                                )
                            )
                            continue
                        }
                    }
                    guard hasImportableCredentials(authJSONString: raw) else {
                        var failureReason = enrichment.failureReason ?? "Missing required credentials"
                        if let parsed = try? JSON(data: normalizedData),
                           case let .invalid(reason) = credentialIdentityValidationResult(from: parsed)
                        {
                            failureReason = reason
                        }
                        results.append(
                            CodexImportValidationResult(
                                fileURL: candidateURL,
                                sourceGroupID: sourceGroupID,
                                sourceGroupLabel: sourceGroupLabel,
                                isValid: false,
                                reason: failureReason,
                                suggestedName: nil,
                                email: nil,
                                authJSONString: nil
                            )
                        )
                        continue
                    }
                    results.append(
                        CodexImportValidationResult(
                            fileURL: candidateURL,
                            sourceGroupID: sourceGroupID,
                            sourceGroupLabel: sourceGroupLabel,
                            isValid: true,
                            reason: nil,
                            suggestedName: deriveAccountName(fromAuthJSONString: raw),
                            email: deriveEmail(fromAuthJSONString: raw),
                            authJSONString: raw
                        )
                    )
                }
            } catch {
                results.append(
                    CodexImportValidationResult(
                        fileURL: url,
                        sourceGroupID: url.standardizedFileURL.path,
                        sourceGroupLabel: url.lastPathComponent,
                        isValid: false,
                        reason: error.localizedDescription,
                        suggestedName: nil,
                        email: nil,
                        authJSONString: nil
                    )
                )
            }
        }
        return results
    }

    @discardableResult
    public func importValidatedAuthFiles(
        results: [CodexImportValidationResult],
        destination: ImportDestination = .managedSnapshots
    ) async throws -> [CodexAuthAccount] {
        switch destination {
        case .managedSnapshots:
            var imported: [CodexAuthAccount] = []
            for result in results where result.isValid {
                guard let raw = result.authJSONString else { continue }
                let finalName = result.suggestedName ?? deriveAccountName(fromAuthJSONString: raw)
                let account = try await addAccount(name: finalName, authJSONString: raw)
                imported.append(account)
            }
            return imported
        case let .customSQLiteGroup(name):
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw CocoaError(.validationMissingMandatoryProperty, userInfo: [
                    NSLocalizedDescriptionKey: "Custom import group name is required.",
                ])
            }
            var imported: [CodexAuthAccount] = []
            for result in results where result.isValid {
                guard let raw = result.authJSONString else { continue }
                let finalName = result.suggestedName ?? deriveAccountName(fromAuthJSONString: raw)
                let account = try await addAccount(name: finalName, authJSONString: raw)
                try setCustomSQLiteGroup(trimmedName, for: account.id)
                imported.append(account)
            }
            try await persistValidatedImportsToSQLiteGroup(results: results, groupName: trimmedName)
            return imported
        }
    }

    func importCandidates(for url: URL) throws -> [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] {
        try CodexAuthManagerSupport.importCandidates(for: url).map {
            ($0.candidateURL, $0.sourceGroupID, $0.sourceGroupLabel, $0.data)
        }
    }

    struct ImportEnrichmentResult {
        let data: Data
        let failureReason: String?
    }

    func enrichImportedAuthDataIfNeeded(_ data: Data) async -> ImportEnrichmentResult {
        guard var root = Self.decodeJSONObject(from: data) else {
            return ImportEnrichmentResult(data: data, failureReason: nil)
        }

        var changed = false
        var failureReason: String?
        var tokens = (root["tokens"] as? JSONObject) ?? [:]

        let idTokenBefore = firstNonEmptyString(in: root, keys: ["tokens.id_token", "tokens.idToken", "id_token", "idToken"])
        let accessTokenBefore = firstNonEmptyString(in: root, keys: ["tokens.access_token", "tokens.accessToken", "access_token", "accessToken"])
        let refreshToken = firstNonEmptyString(in: root, keys: ["tokens.refresh_token", "tokens.refreshToken", "refresh_token", "refreshToken"])

        // Compatibility for legacy Codex exports where `access_token` carries JWT claims while `id_token` is empty.
        if idTokenBefore == nil,
           let accessTokenBefore,
           CodexAuthSummary.decodeJWTPayloadJSON(accessTokenBefore) != nil
        {
            tokens["id_token"] = accessTokenBefore
            changed = true
        }

        if (idTokenBefore == nil || accessTokenBefore == nil), let refreshToken {
            do {
                let refreshed = try await refreshCodexTokenAction(refreshToken)
                tokens["id_token"] = refreshed.idToken
                tokens["access_token"] = refreshed.accessToken
                if let refreshedToken = refreshed.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines), !refreshedToken.isEmpty {
                    tokens["refresh_token"] = refreshedToken
                } else if tokens["refresh_token"] == nil {
                    tokens["refresh_token"] = refreshToken
                }
                if let expiresIn = refreshed.expiresIn, expiresIn > 0 {
                    let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                    root["expires_at"] = Self.makeISOFormatter().string(from: expiresAt)
                }
                changed = true
            } catch {
                failureReason = "Token refresh failed: \(error.localizedDescription)"
            }
        }

        let idToken = firstNonEmptyString(in: tokens, keys: ["id_token", "idToken"])
            ?? firstNonEmptyString(in: root, keys: ["id_token", "idToken"])
        let payload = idToken.flatMap(CodexAuthSummary.decodeJWTPayloadJSON)
        let rootJSON: JSON = {
            guard let rootData = try? Self.encodeJSONObject(root) else { return JSON.null }
            return (try? JSON(data: rootData)) ?? .null
        }()
        let accountID = CodexAuthSummary.canonicalAccountID(json: rootJSON, payload: payload)
        if let accountID {
            if firstNonEmptyString(in: tokens, keys: ["account_id", "accountId"]) == nil {
                tokens["account_id"] = accountID
                changed = true
            }
            if firstNonEmptyString(in: root, keys: ["chatgpt_account_id", "chatgptAccountId", "account_id", "accountId"]) == nil {
                root["chatgpt_account_id"] = accountID
                changed = true
            }
        }

        if let derivedEmail = deriveEmail(from: rootJSON) ?? firstNonEmptyString(in: payload, paths: [["email"], ["https://api.openai.com/auth", "email"], ["auth", "email"]]),
           firstNonEmptyString(in: root, keys: ["email", "user.email", "nolon.account.email"]) == nil
        {
            root["email"] = derivedEmail
            changed = true
        }

        let derivedPlanType = firstNonEmptyString(in: root, keys: ["plan_type", "planType", "plan", "subscription.plan", "account.plan"])
            ?? firstNonEmptyString(in: payload, paths: [["https://api.openai.com/auth", "chatgpt_plan_type"], ["auth", "chatgpt_plan_type"], ["plan"]])
        if let derivedPlanType {
            if firstNonEmptyString(in: root, keys: ["plan_type", "planType"]) == nil {
                root["plan_type"] = derivedPlanType
                changed = true
            }
            if firstNonEmptyString(in: root, keys: ["plan", "subscription.plan", "account.plan"]) == nil {
                root["plan"] = derivedPlanType
                changed = true
            }
        }

        let hasOAuthTokenPair = firstNonEmptyString(in: tokens, keys: ["id_token", "idToken"]) != nil
            && firstNonEmptyString(in: tokens, keys: ["access_token", "accessToken"]) != nil
        if hasOAuthTokenPair, firstNonEmptyString(in: root, keys: ["auth_mode"]) == nil {
            root["auth_mode"] = Self.canonicalChatGPTAuthMode
            changed = true
        }

        let accessToken = firstNonEmptyString(in: tokens, keys: ["access_token", "accessToken"])
            ?? firstNonEmptyString(in: root, keys: ["access_token", "accessToken"])
        if let accessToken {
            do {
                if let fetched = try await fetchCodexAccountInfoAction(accessToken) {
                    if let fetchedEmail = fetched.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedEmail.isEmpty,
                       firstNonEmptyString(in: root, keys: ["email", "user.email", "nolon.account.email"]) == nil
                    {
                        root["email"] = fetchedEmail
                        changed = true
                    }
                    if let fetchedAccountID = fetched.accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedAccountID.isEmpty
                    {
                        if firstNonEmptyString(in: tokens, keys: ["account_id", "accountId"]) == nil {
                            tokens["account_id"] = fetchedAccountID
                            changed = true
                        }
                        if firstNonEmptyString(in: root, keys: ["chatgpt_account_id", "chatgptAccountId", "account_id", "accountId"]) == nil {
                            root["chatgpt_account_id"] = fetchedAccountID
                            changed = true
                        }
                    }
                    if let fetchedPlan = fetched.planType?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedPlan.isEmpty
                    {
                        if firstNonEmptyString(in: root, keys: ["plan_type", "planType"]) == nil {
                            root["plan_type"] = fetchedPlan
                            changed = true
                        }
                        if firstNonEmptyString(in: root, keys: ["plan", "subscription.plan", "account.plan"]) == nil {
                            root["plan"] = fetchedPlan
                            changed = true
                        }
                    }
                }
            } catch {
                // Ignore resource fetch failures and keep local/JWT-derived enrichment as fallback.
            }
        }

        if changed {
            root["tokens"] = tokens
            if let encoded = try? Self.encodeJSONObject(root) {
                return ImportEnrichmentResult(data: encoded, failureReason: failureReason)
            }
        }
        return ImportEnrichmentResult(data: data, failureReason: failureReason)
    }

    nonisolated static func defaultRefreshCodexOAuthTokens(refreshToken: String) async throws -> RefreshedOAuthTokens {
        try await CodexAuthManagerSupport.refreshOAuthTokens(refreshToken: refreshToken)
    }

    nonisolated static func defaultFetchCodexOAuthAccountInfo(accessToken: String) async throws -> FetchedOAuthAccountInfo? {
        try await CodexAuthManagerSupport.fetchOAuthAccountInfo(accessToken: accessToken)
    }

    func firstNonEmptyString(in object: JSONObject, keys: [String]) -> String? {
        CodexAuthManagerSupport.firstNonEmptyString(in: object, keys: keys)
    }

    func runDitto(arguments: [String]) throws {
        try CodexAuthManagerSupport.runDitto(arguments: arguments)
    }
}

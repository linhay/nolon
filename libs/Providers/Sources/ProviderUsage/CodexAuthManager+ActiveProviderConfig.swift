import Foundation
import ProviderCatalog
import STFilePath

extension CodexAuthManager {
    private struct ResolvedRelayConfig {
        let relay: CodexActiveProviderConfigManager.RelayConfig
        let inferredProviderID: String?
    }

    private struct ParsedManagedProviderConfig {
        let currentProviderID: String?
        let baseURLsByProviderID: [String: String]
        let queryParamsByProviderID: [String: [String: String]]
        let httpHeadersByProviderID: [String: [String: String]]
    }

    private enum ActiveProviderConfigIntent {
        case apply(CodexActiveProviderConfigManager.RelayConfig)
        case restore
        case skip
    }

    nonisolated func activeProviderConfigStateFile() -> STFile {
        nolonCodexRootFolder().folder("active-provider-config").file("config.json")
    }

    func activeProviderConfigManager() -> CodexActiveProviderConfigManager {
        CodexActiveProviderConfigManager(
            stateStore: CodexActiveProviderConfigStateStore(file: activeProviderConfigStateFile())
        )
    }

    func sessionProviderMigrationManager() -> CodexSessionProviderMigrationManager {
        CodexSessionProviderMigrationManager()
    }

    public func configFile(for provider: Provider) -> STFile? {
        codexHomeFolder(for: provider)?.file("config.toml")
    }

    func readOnlyRelayConfigEvidence(
        for provider: Provider,
        matchedAccountID: UUID?
    ) -> ConfiguredRelay? {
        guard let matchedAccountID,
              let configFile = configFile(for: provider),
              let managedState = activeProviderConfigManager().managedState(configFile: configFile),
              managedState.managedAccountID == matchedAccountID,
              configFile.isExists,
              let raw = try? configFile.read(),
              !raw.isEmpty
        else {
            return nil
        }

        let parsed = parseManagedProviderConfig(raw)
        guard let currentProviderID = parsed.currentProviderID,
              normalizedManagedProviderID(managedState.managedProviderID) == currentProviderID,
              let baseURL = parsed.baseURLsByProviderID[currentProviderID],
              normalizedBaseURL(baseURL) != nil
        else {
            return nil
        }

        return ConfiguredRelay(
            baseURL: baseURL,
            modelProvider: currentProviderID,
            queryParams: parsed.queryParamsByProviderID[currentProviderID] ?? [:],
            headers: parsed.httpHeadersByProviderID[currentProviderID] ?? [:]
        )
    }

    func syncActiveProviderConfig(for account: CodexAuthAccount, provider: Provider) throws {
        guard Self.isCodexTemplate(provider.templateId),
              let configFile = configFile(for: provider),
              let codexHome = codexHomeFolder(for: provider)
        else {
            return
        }

        let configManager = activeProviderConfigManager()
        let migrationManager = sessionProviderMigrationManager()
        let previousManagedProviderID = configManager.managedState(configFile: configFile)?.managedProviderID
        let baselineProviderID = configManager.baselineProviderID(configFile: configFile)

        switch try activeProviderConfigIntent(for: account, configFile: configFile) {
        case let .apply(relay):
            try configManager.applyRelayConfig(configFile: configFile, relay: relay)
            let sourceProviderIDs = migrationSourceProviderIDs(
                baselineProviderID: baselineProviderID,
                previousManagedProviderID: previousManagedProviderID,
                targetProviderID: relay.providerID
            )
            if !sourceProviderIDs.isEmpty {
                migrationManager.migrateSessionProviders(
                    codexHome: codexHome,
                    sourceProviderIDs: sourceProviderIDs,
                    targetProviderID: relay.providerID
                )
            }
        case .restore:
            try configManager.restoreManagedConfig(configFile: configFile)
            if let previousManagedProviderID,
               normalizedManagedProviderID(previousManagedProviderID) != normalizedManagedProviderID(baselineProviderID)
            {
                migrationManager.migrateSessionProviders(
                    codexHome: codexHome,
                    sourceProviderIDs: [previousManagedProviderID],
                    targetProviderID: baselineProviderID
                )
            }
        case .skip:
            return
        }
    }

    public func refreshActiveProviderFilesIfNeeded(
        for account: CodexAuthAccount,
        provider: Provider,
        syncRuntimeConfig: Bool
    ) throws {
        let activeID = resolveActiveAccountID(from: loadActiveAccountMap(), for: provider)
        guard activeID == account.id.uuidString else {
            return
        }
        try withAuthFileLock {
            if syncRuntimeConfig {
                try syncActiveProviderConfig(for: account, provider: provider)
            }
            // Keep the provider-facing auth.json in sync with the latest SQLite snapshot
            // after editing the currently active configured account.
            try activateAccount(account, for: provider)
        }
    }

    public func refreshActiveProviderConfigIfNeeded(for account: CodexAuthAccount, provider: Provider) throws {
        try refreshActiveProviderFilesIfNeeded(for: account, provider: provider, syncRuntimeConfig: true)
    }

    private func activeProviderConfigIntent(
        for account: CodexAuthAccount,
        configFile: STFile
    ) throws -> ActiveProviderConfigIntent {
        let data = try readAccountAuthData(account)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let object = jsonObject as? [String: Any] else {
            return .restore
        }

        let authMode = Self.canonicalAuthMode(trimmedString(object["auth_mode"]))
        guard authMode == "apikey" else {
            return .restore
        }

        guard let resolvedRelay = relayConfig(from: object, accountID: account.id, configFile: configFile) else {
            return .restore
        }
        if let inferredProviderID = resolvedRelay.inferredProviderID {
            try persistInferredRelayModelProvider(
                inferredProviderID,
                baseURL: resolvedRelay.relay.baseURL,
                for: account,
                object: object
            )
        }
        return .apply(resolvedRelay.relay)
    }

    private func relayConfig(
        from object: [String: Any],
        accountID: UUID,
        configFile: STFile
    ) -> ResolvedRelayConfig? {
        guard let nolon = object["nolon"] as? [String: Any],
              let relay = nolon["relay"] as? [String: Any],
              let baseURL = trimmedString(relay["base_url"])
        else {
            return nil
        }

        let explicitProviderID = normalizedManagedProviderID(trimmedString(relay["model_provider"]))
        let inferredProviderID: String?
        let resolvedProviderID: String
        if let explicitProviderID {
            resolvedProviderID = explicitProviderID
            inferredProviderID = nil
        } else if let candidate = inferManagedProviderID(from: configFile, matchingBaseURL: baseURL) {
            resolvedProviderID = candidate
            inferredProviderID = candidate
        } else {
            return nil
        }

        let queryParams = stringDictionary(relay["query_params"])
        let httpHeaders = stringDictionary(relay["headers"])
        return ResolvedRelayConfig(
            relay: CodexActiveProviderConfigManager.RelayConfig(
                accountID: accountID,
                providerID: resolvedProviderID,
                providerName: resolvedProviderID,
                baseURL: baseURL,
                queryParams: queryParams,
                httpHeaders: httpHeaders,
                model: "gpt-5.4",
                modelReasoningEffort: "xhigh"
            ),
            inferredProviderID: inferredProviderID
        )
    }

    private func normalizedManagedProviderID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }

        let sanitized = raw
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? nil : sanitized
    }

    private func migrationSourceProviderIDs(
        baselineProviderID: String,
        previousManagedProviderID: String?,
        targetProviderID: String
    ) -> [String] {
        if normalizedManagedProviderID(previousManagedProviderID) == normalizedManagedProviderID(targetProviderID) {
            return []
        }

        var seen: Set<String> = []
        return [baselineProviderID, previousManagedProviderID]
            .compactMap { normalizedManagedProviderID($0) }
            .filter { sourceProviderID in
                guard sourceProviderID != targetProviderID else { return false }
                return seen.insert(sourceProviderID).inserted
            }
    }

    private func trimmedString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stringDictionary(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        result.reserveCapacity(raw.count)
        for key in raw.keys.sorted() {
            guard let trimmedKey = trimmedString(key),
                  let trimmedValue = trimmedString(raw[key])
            else {
                continue
            }
            result[trimmedKey] = trimmedValue
        }
        return result
    }

    private func persistInferredRelayModelProvider(
        _ providerID: String,
        baseURL: String,
        for account: CodexAuthAccount,
        object: [String: Any]
    ) throws {
        var repaired = object
        repaired["base_url"] = baseURL
        repaired.removeValue(forKey: "baseURL")

        var nolon = (repaired["nolon"] as? [String: Any]) ?? [:]
        var relay = (nolon["relay"] as? [String: Any]) ?? [:]
        relay["base_url"] = baseURL
        relay["model_provider"] = providerID
        nolon["relay"] = relay
        repaired["nolon"] = nolon

        let data = try JSONSerialization.data(withJSONObject: repaired, options: [])
        try saveAccountAuthData(account, data: data)
    }

    private func inferManagedProviderID(from configFile: STFile, matchingBaseURL baseURL: String) -> String? {
        guard configFile.isExists,
              let raw = try? configFile.read(),
              !raw.isEmpty,
              let normalizedRelayBaseURL = normalizedBaseURL(baseURL)
        else {
            return nil
        }

        let parsed = parseManagedProviderConfig(raw)
        if let currentProviderID = parsed.currentProviderID,
           let currentBaseURL = parsed.baseURLsByProviderID[currentProviderID],
           normalizedBaseURL(currentBaseURL) == normalizedRelayBaseURL
        {
            return currentProviderID
        }

        let matches = parsed.baseURLsByProviderID.compactMap { providerID, candidateBaseURL -> String? in
            guard normalizedBaseURL(candidateBaseURL) == normalizedRelayBaseURL else {
                return nil
            }
            return providerID
        }

        guard matches.count == 1 else {
            return nil
        }
        return matches[0]
    }

    private func parseManagedProviderConfig(_ raw: String) -> ParsedManagedProviderConfig {
        var currentProviderID: String?
        var currentSectionProviderID: String?
        var baseURLsByProviderID: [String: String] = [:]
        var queryParamsByProviderID: [String: [String: String]] = [:]
        var httpHeadersByProviderID: [String: [String: String]] = [:]

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if let sectionProviderID = modelProviderSectionID(from: line) {
                currentSectionProviderID = sectionProviderID
                continue
            }
            if line.hasPrefix("["), line.hasSuffix("]") {
                currentSectionProviderID = nil
                continue
            }

            if currentSectionProviderID == nil,
               let providerID = normalizedManagedProviderID(quotedAssignmentValue(from: line, key: "model_provider"))
            {
                currentProviderID = providerID
            }
            if let currentSectionProviderID,
               let baseURL = quotedAssignmentValue(from: line, key: "base_url")
            {
                baseURLsByProviderID[currentSectionProviderID] = baseURL
            }
            if let currentSectionProviderID,
               let queryParams = inlineTableAssignmentValue(from: line, key: "query_params")
            {
                queryParamsByProviderID[currentSectionProviderID] = queryParams
            }
            if let currentSectionProviderID,
               let httpHeaders = inlineTableAssignmentValue(from: line, key: "http_headers")
            {
                httpHeadersByProviderID[currentSectionProviderID] = httpHeaders
            }
        }

        return ParsedManagedProviderConfig(
            currentProviderID: currentProviderID,
            baseURLsByProviderID: baseURLsByProviderID,
            queryParamsByProviderID: queryParamsByProviderID,
            httpHeadersByProviderID: httpHeadersByProviderID
        )
    }

    private func modelProviderSectionID(from line: String) -> String? {
        let prefix = "[model_providers."
        guard line.hasPrefix(prefix), line.hasSuffix("]"), line.count > prefix.count + 1 else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        let end = line.index(before: line.endIndex)
        return normalizedManagedProviderID(String(line[start..<end]))
    }

    private func quotedAssignmentValue(from line: String, key: String) -> String? {
        guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
        let left = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard left == key else { return nil }

        let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.first == "\"",
              let closingQuote = rawValue.dropFirst().firstIndex(of: "\"")
        else {
            return nil
        }

        return String(rawValue[rawValue.index(after: rawValue.startIndex)..<closingQuote])
    }

    private func inlineTableAssignmentValue(from line: String, key: String) -> [String: String]? {
        guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
        let left = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard left == key else { return nil }

        let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.first == "{", rawValue.last == "}" else {
            return nil
        }

        let content = rawValue.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return [:] }

        var result: [String: String] = [:]
        for pair in content.split(separator: ",", omittingEmptySubsequences: true) {
            guard let pairSeparator = pair.firstIndex(of: "=") else { continue }
            let rawKey = pair[..<pairSeparator].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawQuotedValue = pair[pair.index(after: pairSeparator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawKey.isEmpty,
                  rawQuotedValue.first == "\"",
                  let closingQuote = rawQuotedValue.dropFirst().firstIndex(of: "\"")
            else {
                continue
            }
            let rawStringValue = String(rawQuotedValue[rawQuotedValue.index(after: rawQuotedValue.startIndex)..<closingQuote])
            guard let key = trimmedString(rawKey),
                  let value = trimmedString(rawStringValue)
            else {
                continue
            }
            result[key] = value
        }
        return result
    }

    private func normalizedBaseURL(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }

        if var components = URLComponents(string: raw) {
            components.scheme = components.scheme?.lowercased()
            components.host = components.host?.lowercased()
            let candidate = components.string ?? raw
            return candidate.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

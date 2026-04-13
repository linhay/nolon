import Foundation
import ProviderCatalog
import STFilePath

extension CodexAuthManager {
    private struct ResolvedRelayConfig {
        let relay: CodexActiveProviderConfigManager.RelayConfig
        let inferredProviderID: String?
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
            migrationManager.migrateSessionProviders(
                codexHome: codexHome,
                sourceProviderIDs: [baselineProviderID, previousManagedProviderID].compactMap { $0 },
                targetProviderID: relay.providerID
            )
        case .restore:
            try configManager.restoreManagedConfig(configFile: configFile)
            if let previousManagedProviderID {
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

    public func refreshActiveProviderConfigIfNeeded(for account: CodexAuthAccount, provider: Provider) throws {
        let activeID = resolveActiveAccountID(from: loadActiveAccountMap(), for: provider)
        guard activeID == account.id.uuidString else {
            return
        }
        try withAuthFileLock {
            try syncActiveProviderConfig(for: account, provider: provider)
        }
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

    private func parseManagedProviderConfig(
        _ raw: String
    ) -> (currentProviderID: String?, baseURLsByProviderID: [String: String]) {
        var currentProviderID: String?
        var currentSectionProviderID: String?
        var baseURLsByProviderID: [String: String] = [:]

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
        }

        return (currentProviderID, baseURLsByProviderID)
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

import Foundation
import ProviderUsage
import CodexProvider
import STJSON

@MainActor
extension ProviderUsageViewModel {
    func makeCodexUsageQuery(from draft: CodexConfigEditorDraft) throws -> CodexHTTPUsageQuery? {
        let hasAnyHTTPField =
            draft.httpUsageEnabled
            || isNotBlank(draft.httpUsageURL)
            || isNotBlank(draft.httpUsageHeadersText)
            || isNotBlank(draft.httpUsageBody)
            || isNotBlank(draft.httpUsagePlanPath)
            || isNotBlank(draft.httpUsageCreditsRemainingPath)
            || isNotBlank(draft.httpUsageUsedPath)
            || isNotBlank(draft.httpUsageTotalPath)
            || isNotBlank(draft.httpUsageCostTodayPath)
            || isNotBlank(draft.httpUsageCostLast30DaysPath)
            || isNotBlank(draft.httpUsageErrorMessagePath)
            || isNotBlank(draft.httpUsageOverrideBaseURL)
            || isNotBlank(draft.httpUsageOverrideAPIKey)
            || isNotBlank(draft.httpUsageOverrideAccessToken)
            || isNotBlank(draft.httpUsageOverrideUserID)

        guard hasAnyHTTPField else { return nil }

        guard draft.httpUsageEnabled else {
            return CodexHTTPUsageQuery(
                enabled: false,
                credentials: nil,
                mapping: nil
            )
        }

        let url = trimmed(draft.httpUsageURL)
        let usesBaseURLTemplate = url.contains("{{baseURL}}")
        guard
            isNotBlank(url),
            usesBaseURLTemplate || (URL(string: url)?.scheme != nil)
        else {
            throw NSError(
                domain: "ProviderUsageViewModel.CodexUsageQuery",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.http_usage.error.url_required",
                    value: "Please provide a valid HTTP usage URL.",
                    comment: "HTTP usage URL required"
                )]
            )
        }

        let headers = try Self.parseKeyValueLines(draft.httpUsageHeadersText)
        let method: CodexHTTPMethod = isNotBlank(draft.httpUsageBody) ? .post : .get
        let timeoutSeconds: Double? = {
            let raw = trimmed(draft.httpUsageTimeoutSeconds)
            guard let value = Double(raw), value > 0 else { return nil }
            return value
        }()
        let request = CodexHTTPUsageQueryRequest(
            method: method,
            url: url,
            headers: headers.isEmpty ? nil : headers,
            body: emptyToNil(draft.httpUsageBody)
        )

        let query = CodexHTTPUsageQuery(
            enabled: true,
            timeoutSeconds: timeoutSeconds,
            request: request,
            credentials: .init(
                baseURL: emptyToNil(draft.httpUsageOverrideBaseURL),
                apiKey: emptyToNil(draft.httpUsageOverrideAPIKey),
                accessToken: emptyToNil(draft.httpUsageOverrideAccessToken),
                userID: emptyToNil(draft.httpUsageOverrideUserID)
            ),
            mapping: .init(
                planPath: emptyToNil(draft.httpUsagePlanPath),
                creditsRemainingPath: emptyToNil(draft.httpUsageCreditsRemainingPath),
                usageUsedPath: emptyToNil(draft.httpUsageUsedPath),
                usageTotalPath: emptyToNil(draft.httpUsageTotalPath),
                costTodayUSDPath: emptyToNil(draft.httpUsageCostTodayPath),
                costLast30DaysUSDPath: emptyToNil(draft.httpUsageCostLast30DaysPath),
                errorMessagePath: emptyToNil(draft.httpUsageErrorMessagePath)
            )
        )

        if query.mapping?.planPath == nil,
           query.mapping?.creditsRemainingPath == nil,
           query.mapping?.usageUsedPath == nil,
           query.mapping?.usageTotalPath == nil,
           query.mapping?.costTodayUSDPath == nil,
           query.mapping?.costLast30DaysUSDPath == nil
        {
            throw NSError(
                domain: "ProviderUsageViewModel.CodexUsageQuery",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.http_usage.error.mapping_required",
                    value: "At least one HTTP usage mapping path is required.",
                    comment: "HTTP usage mapping required"
                )]
            )
        }

        return query
    }

    func makeCodexUsageQueryResolvedConfiguration(
        from draft: CodexConfigEditorDraft,
        query: CodexHTTPUsageQuery
    ) throws -> CodexHTTPUsageQueryResolvedConfiguration {
        let defaultCredentials = CodexHTTPUsageQueryCredentials(
            baseURL: emptyToNil(draft.baseURL),
            apiKey: emptyToNil(draft.apiKey),
            accessToken: nil,
            userID: nil
        )
        let cardKind: CodexAuthSummary.CardKind? = {
            switch draft.mode {
            case .newAPIKey:
                return .officialAPIKey
            case .newRelay:
                return .relayProfile
            case let .edit(accountID):
                return codexAccountSummaries[accountID]?.cardKind ?? (draft.isRelay ? .relayProfile : .officialAPIKey)
            }
        }()

        return CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: defaultCredentials,
            cardKind: cardKind,
            source: .explicit
        )
    }

    static func codexUsageQueryTestSummary(result: ProviderFetchResult) -> String {
        var parts: [String] = []
        if let plan = result.usage.identity?.plan, !plan.isEmpty {
            parts.append("Plan: \(plan)")
        }
        if let credits = result.credits?.remaining, !credits.isNaN {
            parts.append("Credits: \(credits)")
        }
        if let usedPercent = result.usage.primary?.usedPercent {
            parts.append("Used: \(Int(usedPercent.rounded()))%")
        }
        if let todayCost = result.cost?.todayCostUSD {
            parts.append("Today: $\(todayCost)")
        }
        if let last30Days = result.cost?.last30DaysCostUSD {
            parts.append("30D: $\(last30Days)")
        }
        if parts.isEmpty {
            return NSLocalizedString(
                "codex.accounts.http_usage.test.success",
                value: "HTTP usage query succeeded.",
                comment: "HTTP usage test success"
            )
        }
        return parts.joined(separator: " · ")
    }

    func emptyToNil(_ raw: String) -> String? {
        let trimmed = trimmed(raw)
        return isNotBlank(trimmed) ? trimmed : nil
    }

    func mergeCodexImportCandidates(results: [CodexAuthManager.CodexImportValidationResult]) {
        var mergedByPath: [String: CodexImportCandidate] = Dictionary(
            uniqueKeysWithValues: codexImportCandidates.map { candidate in
                (candidate.sourceFileURL.standardizedFileURL.path, candidate)
            }
        )

        for result in results {
            let candidate = makeCodexImportCandidate(result: result)
            mergedByPath[candidate.sourceFileURL.standardizedFileURL.path] = candidate
        }

        codexImportCandidates = mergedByPath.values.sorted {
            $0.sourceFileURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceFileURL.lastPathComponent) == .orderedAscending
        }
        pendingImportValidationResults = codexImportCandidates.map(\.validation)
        importValidationSummaryMessage = codexImportCandidates
            .filter { !$0.validation.isValid }
            .compactMap { candidate in
                guard let reason = candidate.validation.reason else { return nil }
                return "\(candidate.sourceFileURL.lastPathComponent): \(reason)"
            }
            .joined(separator: "\n")
    }

    func normalizeCodexImportText(_ raw: String) throws -> (authJSONString: String, fileExtension: String) {
        if let authJSONString = try? CodexLoginRunner.authJSONString(fromSuccessCallbackURLString: raw) {
            return (authJSONString, "json")
        }
        return (raw, "json")
    }

    var filteredCodexImportCandidates: [CodexImportCandidate] {
        let keyword = normalizedCodexImportSearchKeyword
        guard !keyword.isEmpty else { return codexImportCandidates }
        return codexImportCandidates.filter { candidate in
            codexImportSearchTokens(for: candidate).contains { token in
                normalizedCodexImportSearchValue(token).contains(keyword)
            }
        }
    }

    private var normalizedCodexImportSearchKeyword: String {
        normalizedCodexImportSearchValue(codexImportSearchText)
    }

    private func codexImportSearchTokens(for candidate: CodexImportCandidate) -> [String] {
        [
            candidate.validation.suggestedName,
            candidate.validation.email,
            candidate.sourceFileURL.lastPathComponent,
            candidate.validation.sourceGroupLabel,
            candidate.validation.reason,
            candidate.testSummary
        ].compactMap { value in
            guard let value else { return nil }
            let trimmedValue = trimmed(value)
            return trimmedValue.isEmpty ? nil : trimmedValue
        }
    }

    private func normalizedCodexImportSearchValue(_ raw: String) -> String {
        trimmed(raw)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    func makePastedCodexImportURL(for fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-import-pasted-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    func makeCodexImportCandidate(
        result: CodexAuthManager.CodexImportValidationResult
    ) -> CodexImportCandidate {
        let failureSummary = result.reason.map { trimmed($0) }
        return CodexImportCandidate(
            sourceFileURL: result.fileURL,
            validation: result,
            isSelected: result.isValid,
            testStatus: result.isValid ? .idle : .failure,
            testSummary: result.isValid ? nil : failureSummary,
            testDetail: result.isValid ? nil : failureSummary
        )
    }

    func runCodexImportConnectionTests(for ids: [UUID]) async {
        let validIDs = Set(ids)
        guard !validIDs.isEmpty else { return }
        isRunningCodexImportConnectionTests = true
        defer { isRunningCodexImportConnectionTests = false }

        codexImportCandidates = codexImportCandidates.map { candidate in
            guard validIDs.contains(candidate.id), candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.testStatus = .testing
            updated.testSummary = nil
            updated.testDetail = nil
            return updated
        }

        await withTaskGroup(of: (UUID, ProviderAccountUsageOutcome).self) { group in
            for candidate in codexImportCandidates where validIDs.contains(candidate.id) && candidate.validation.isValid {
                let validation = candidate.validation
                let settingsSnapshot = settings
                group.addTask { [codexImportConnectionTestAction] in
                    let outcome = await codexImportConnectionTestAction(validation, settingsSnapshot)
                    return (candidate.id, outcome)
                }
            }

            for await (id, outcome) in group {
                applyCodexImportConnectionTestResult(outcome, for: id)
            }
        }
    }

    func applyCodexImportConnectionTestResult(_ outcome: ProviderAccountUsageOutcome, for id: UUID) {
        guard let index = codexImportCandidates.firstIndex(where: { $0.id == id }) else { return }
        var candidate = codexImportCandidates[index]
        switch outcome.outcome.result {
        case let .success(result):
            candidate.testStatus = .success
            candidate.testSummary = Self.codexImportTestSummary(result: result)
            candidate.testDetail = nil
        case let .failure(error):
            candidate.testStatus = .failure
            candidate.testSummary = Self.errorSummaryText(error: error)
            candidate.testDetail = Self.errorDetailText(error: error)
        }
        codexImportCandidates[index] = candidate
    }

    static func codexImportTestSummary(result: ProviderFetchResult) -> String {
        var parts: [String] = []
        let source = result.sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            parts.append(source)
        }
        if let plan = result.usage.identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines), isNotBlank(plan) {
            parts.append(plan)
        }
        if let remaining = result.credits?.remaining, !remaining.isNaN {
            parts.append("Credits \(Int(remaining.rounded()))")
        } else if let usedPercent = result.usage.primary?.usedPercent {
            parts.append("Used \(Int(usedPercent.rounded()))%")
        }
        return parts.isEmpty ? NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status") : parts.joined(separator: " · ")
    }
}

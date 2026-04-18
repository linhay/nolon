import XCTest
import ProviderCatalog
import CodexProvider
import NolonResourceKit
import STFilePath
@testable import nolon

@MainActor
final class CodexSessionsTabViewModelTests: XCTestCase {
    func testBDD_GivenProjectSessions_WhenLoading_ThenProjectGroupingIsDefaultAndRowsSortNewestFirst() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a-1.jsonl",
                    threadID: "thread-a-1",
                    title: "Project Alpha Older",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
                makeSession(
                    id: "sessions/a-2.jsonl",
                    threadID: "thread-a-2",
                    title: "Project Alpha Newer",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_100
                ),
                makeSession(
                    id: "sessions/b-1.jsonl",
                    threadID: "thread-b-1",
                    title: "Project Beta Latest",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-beta",
                    updatedAt: 1_200
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let serviceState = MockCodexSessionsServiceState(snapshots: [snapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.groupingMode, .project)
        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections[0].title, "project-beta")
        XCTAssertEqual(viewModel.sections[1].title, "project-alpha")
        let projectAlphaSessionIDs = viewModel.sections[1].sessions.map { $0.id }
        XCTAssertEqual(projectAlphaSessionIDs, ["sessions/a-2.jsonl", "sessions/a-1.jsonl"])
    }

    func testBDD_GivenProjectSectionWithMoreThanFiveRows_WhenTogglingExpansion_ThenVisibleRowsSwitchBetweenFiveAndAll() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<8).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_500 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai", "anthropic"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()

        let sectionID = try XCTUnwrap(viewModel.sections.first?.id)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 5)
        XCTAssertEqual(viewModel.sections.first?.remainingSessionCount, 3)
        XCTAssertFalse(viewModel.sections.first?.isExpanded ?? true)

        viewModel.toggleSectionExpansion(sectionID)

        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 8)
        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)

        viewModel.toggleSectionExpansion(sectionID)

        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 5)
        XCTAssertFalse(viewModel.sections.first?.isExpanded ?? true)
    }

    func testBDD_GivenMixedLiveAndArchivedSessions_WhenSectionIsCollapsed_ThenOnlyTopFiveLiveSessionsAreVisible() async throws {
        let provider = makeCodexProvider()
        let liveSessions = Array(0..<6).map { index in
            makeSession(
                id: "sessions/live-\(index).jsonl",
                threadID: "live-\(index)",
                title: "Live \(index)",
                modelProvider: "openai",
                cwd: "/tmp/project-alpha",
                updatedAt: 2_000 - TimeInterval(index),
                archived: false
            )
        }
        let archivedSessions = Array(0..<4).map { index in
            makeSession(
                id: "sessions/archived-\(index).jsonl",
                threadID: "archived-\(index)",
                title: "Archived \(index)",
                modelProvider: "openai",
                cwd: "/tmp/project-alpha",
                updatedAt: 3_000 - TimeInterval(index),
                archived: true
            )
        }
        let snapshot = CodexSessionSnapshot(
            sessions: liveSessions + archivedSessions,
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()

        let section = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(section.visibleSessionCount, 5)
        XCTAssertEqual(section.sessions.map(\.id), Array(liveSessions.prefix(5).map(\.id)))
        XCTAssertTrue(section.sessions.allSatisfy { !$0.archived })
        XCTAssertEqual(section.remainingSessionCount, 5)
        XCTAssertEqual(viewModel.selectedSessionID, liveSessions.first?.id)

        viewModel.toggleSectionExpansion(section.id)

        let expandedSection = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(expandedSection.visibleSessionCount, 10)
        XCTAssertEqual(expandedSection.sessions.first?.id, archivedSessions.first?.id)
        XCTAssertEqual(expandedSection.sessions.filter(\.archived).count, 4)
    }

    func testBDD_GivenCollapsedProjectSection_WhenRequestingGroupRewrite_ThenAllEditableSessionsAreIncluded() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<7).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_500 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai", "anthropic"]
        )
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [snapshot],
            previewResult: .success(.init(sessionCount: 7, liveSessionCount: 7, archivedSessionCount: 0, stateRowCount: 7))
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.sections.count, 1)
        let section = viewModel.sections[0]
        XCTAssertEqual(section.visibleSessionCount, 5)

        await viewModel.requestRewrite(for: section, targetProviderID: "anthropic")

        XCTAssertEqual(
            serviceState.previewRequests.first?.threadIDs.sorted(),
            (0..<7).map { "thread-\($0)" }
        )
    }

    func testBDD_GivenExpandedProjectSection_WhenRefreshing_ThenOldRowsStayVisibleAndExpansionPersists() async throws {
        let provider = makeCodexProvider()
        let initialSnapshot = CodexSessionSnapshot(
            sessions: Array(0..<6).map { index in
                makeSession(
                    id: "sessions/initial-\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: "Initial \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_600 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai", "anthropic"]
        )
        let refreshedSnapshot = CodexSessionSnapshot(
            sessions: initialSnapshot.sessions + [
                makeSession(
                    id: "sessions/refreshed.jsonl",
                    threadID: "thread-refreshed",
                    title: "Refreshed Latest",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let serviceState = MockCodexSessionsServiceState(snapshots: [initialSnapshot])
        let service = MockCodexSessionsService(state: serviceState)
        let viewModel = CodexSessionsTabViewModel(provider: provider, service: service)

        await viewModel.load()
        let sectionID = try XCTUnwrap(viewModel.sections.first?.id)
        viewModel.toggleSectionExpansion(sectionID)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 6)
        XCTAssertEqual(serviceState.snapshotStreamCallCount, 1)
        XCTAssertEqual(serviceState.loadSnapshotCallCount, 0)

        serviceState.snapshots = [refreshedSnapshot]
        serviceState.snapshotDelayNanoseconds = 80_000_000
        let refreshTask = Task { await viewModel.refresh() }

        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 6)
        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Initial 0")
        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)

        _ = await refreshTask.value

        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 7)
        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Refreshed Latest")
        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)
        XCTAssertEqual(serviceState.snapshotStreamCallCount, 1)
        XCTAssertEqual(serviceState.loadSnapshotCallCount, 1)
    }

    func testBDD_GivenVisibleRows_WhenUsageLoadsAsynchronously_ThenUsageStateUpdatesWithoutResettingExpansion() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<6).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_400 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai"]
        )
        let serviceState = MockCodexSessionsServiceState(snapshots: [snapshot])
        serviceState.usageResults["sessions/0.jsonl"] = Result<CodexSessionTokenTotals?, Error>.success(
            CodexSessionTokenTotals(inputTokens: 2_400, cachedInputTokens: 400, outputTokens: 600)
        )
        serviceState.usageDelayNanoseconds = 20_000_000

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        let sectionID = try XCTUnwrap(viewModel.sections.first?.id)
        viewModel.toggleSectionExpansion(sectionID)

        XCTAssertEqual(
            viewModel.usageState(for: "sessions/0.jsonl"),
            CodexSessionsTabViewModel.SessionUsageState.placeholder
        )

        try await waitUntil {
            if case .loaded = viewModel.usageState(for: "sessions/0.jsonl") {
                return true
            }
            return false
        }

        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 6)
    }

    func testBDD_GivenSelectedSession_WhenTimelineLoads_ThenTimelineStateResolvesWithoutResettingSelection() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/selected.jsonl",
                    threadID: "thread-selected",
                    title: "Selected Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_400
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.timelineResults["sessions/selected.jsonl"] = .success(
            .init(
                startedAt: Date(timeIntervalSince1970: 1_000),
                lastActivityAt: Date(timeIntervalSince1970: 1_300)
            )
        )
        state.timelineDelayNanoseconds = 20_000_000
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/selected.jsonl")
        XCTAssertEqual(viewModel.timelineState(for: "sessions/selected.jsonl"), .placeholder)

        try await waitUntil {
            if state.timelineRequests == ["sessions/selected.jsonl"] {
                return true
            }
            return false
        }

        try await waitUntil {
            if case let .loaded(timeline) = viewModel.timelineState(for: "sessions/selected.jsonl") {
                return timeline.startedAt == Date(timeIntervalSince1970: 1_000)
                    && timeline.lastActivityAt == Date(timeIntervalSince1970: 1_300)
            }
            return false
        }

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/selected.jsonl")
    }

    func testBDD_GivenTimelineWithoutStartedAt_WhenLoadingTimeline_ThenStateKeepsNilStartedAtAndResolvedLastActivity() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/fallback.jsonl",
                    threadID: "thread-fallback",
                    title: "Fallback Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_500
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.timelineResults["sessions/fallback.jsonl"] = .success(
            .init(
                startedAt: nil,
                lastActivityAt: Date(timeIntervalSince1970: 1_450)
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()

        try await waitUntil {
            if case let .loaded(timeline) = viewModel.timelineState(for: "sessions/fallback.jsonl") {
                return timeline.startedAt == nil
                    && timeline.lastActivityAt == Date(timeIntervalSince1970: 1_450)
            }
            return false
        }
    }

    func testBDD_GivenTimelineFails_WhenSelectingSameSessionAgain_ThenViewModelRetriesLoad() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/retry.jsonl",
                    threadID: "thread-retry",
                    title: "Retry Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_600
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.timelineResults["sessions/retry.jsonl"] = .failure(NSError(domain: "timeline", code: 1))
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()

        try await waitUntil {
            viewModel.timelineState(for: "sessions/retry.jsonl") == .failed
        }
        XCTAssertEqual(state.timelineRequests, ["sessions/retry.jsonl"])

        state.timelineResults["sessions/retry.jsonl"] = .success(
            .init(
                startedAt: Date(timeIntervalSince1970: 1_500),
                lastActivityAt: Date(timeIntervalSince1970: 1_590)
            )
        )

        viewModel.selectSession("sessions/retry.jsonl")
        XCTAssertEqual(viewModel.timelineState(for: "sessions/retry.jsonl"), .placeholder)

        try await waitUntil {
            state.timelineRequests == ["sessions/retry.jsonl", "sessions/retry.jsonl"]
        }

        try await waitUntil {
            if case let .loaded(timeline) = viewModel.timelineState(for: "sessions/retry.jsonl") {
                return timeline.startedAt == Date(timeIntervalSince1970: 1_500)
                    && timeline.lastActivityAt == Date(timeIntervalSince1970: 1_590)
            }
            return false
        }
    }

    func testBDD_GivenLoadedSessions_WhenSortingByUsage_ThenRowsReorderByDescendingUsage() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/newest-low.jsonl",
                    threadID: "thread-newest-low",
                    title: "Newest Low Usage",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 3_000
                ),
                makeSession(
                    id: "sessions/older-high.jsonl",
                    threadID: "thread-older-high",
                    title: "Older High Usage",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
                makeSession(
                    id: "sessions/oldest-mid.jsonl",
                    threadID: "thread-oldest-mid",
                    title: "Oldest Mid Usage",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.usageResults["sessions/newest-low.jsonl"] = .success(
            .init(inputTokens: 100, cachedInputTokens: 0, outputTokens: 20)
        )
        state.usageResults["sessions/older-high.jsonl"] = .success(
            .init(inputTokens: 8_000, cachedInputTokens: 0, outputTokens: 2_000)
        )
        state.usageResults["sessions/oldest-mid.jsonl"] = .success(
            .init(inputTokens: 2_000, cachedInputTokens: 0, outputTokens: 500)
        )
        state.usageDelayNanoseconds = 15_000_000

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()
        XCTAssertEqual(
            viewModel.sections.first?.sessions.map(\.id),
            ["sessions/newest-low.jsonl", "sessions/older-high.jsonl", "sessions/oldest-mid.jsonl"]
        )

        viewModel.setSortMode(.usage)

        try await waitUntil {
            viewModel.sections.first?.sessions.map(\.id) == [
                "sessions/older-high.jsonl",
                "sessions/oldest-mid.jsonl",
                "sessions/newest-low.jsonl",
            ]
        }
    }

    func testBDD_GivenLoadedSections_WhenSortingByUsage_ThenGroupsReorderByAggregatedUsageDescending() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/project-alpha-newer.jsonl",
                    threadID: "thread-alpha-newer",
                    title: "Project Alpha Newer",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 4_000
                ),
                makeSession(
                    id: "sessions/project-alpha-older.jsonl",
                    threadID: "thread-alpha-older",
                    title: "Project Alpha Older",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 3_000
                ),
                makeSession(
                    id: "sessions/project-beta-latest.jsonl",
                    threadID: "thread-beta-latest",
                    title: "Project Beta Latest",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-beta",
                    updatedAt: 5_000
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.usageResults["sessions/project-alpha-newer.jsonl"] = .success(
            .init(inputTokens: 6_000, cachedInputTokens: 0, outputTokens: 2_000)
        )
        state.usageResults["sessions/project-alpha-older.jsonl"] = .success(
            .init(inputTokens: 3_000, cachedInputTokens: 0, outputTokens: 1_000)
        )
        state.usageResults["sessions/project-beta-latest.jsonl"] = .success(
            .init(inputTokens: 500, cachedInputTokens: 0, outputTokens: 100)
        )
        state.usageDelayNanoseconds = 15_000_000

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.sections.map(\.title), ["project-beta", "project-alpha"])

        viewModel.setSortMode(.usage)

        try await waitUntil {
            viewModel.sections.map(\.title) == ["project-alpha", "project-beta"]
        }
    }

    func testBDD_GivenUsageSortWithoutResolvedUsage_WhenSorting_ThenRowsFallbackToRecentActivityOrder() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/recent.jsonl",
                    threadID: "thread-recent",
                    title: "Recent",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 3_000
                ),
                makeSession(
                    id: "sessions/older.jsonl",
                    threadID: "thread-older",
                    title: "Older",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        viewModel.setSortMode(.usage)

        XCTAssertEqual(
            viewModel.sections.first?.sessions.map(\.id),
            ["sessions/recent.jsonl", "sessions/older.jsonl"]
        )
    }

    func testBDD_GivenSearchQueryMatchesDisplayID_WhenFiltering_ThenOnlyMatchingRowsRemainVisible() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-alpha-001",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-beta-002",
                    title: "Beta",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-beta",
                    updatedAt: 1_000
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        viewModel.searchQuery = "beta-002"

        try await waitUntil {
            viewModel.sections.count == 1 &&
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/b.jsonl"] &&
            viewModel.selectedSessionID == "sessions/b.jsonl"
        }
    }

    func testBDD_GivenProviderRawIDOrFriendlyName_WhenFiltering_ThenRowsMatchEitherForm() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/openai.jsonl",
                    threadID: "thread-openai",
                    title: "OpenAI Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
                makeSession(
                    id: "sessions/anthropic.jsonl",
                    threadID: "thread-anthropic",
                    title: "Anthropic Session",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-beta",
                    updatedAt: 1_000
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()

        viewModel.searchQuery = "openai"
        try await waitUntil {
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/openai.jsonl"]
        }

        viewModel.searchQuery = "Anthropic"
        try await waitUntil {
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/anthropic.jsonl"]
        }
    }

    func testBDD_GivenCollapsedSectionWhenSearchMatchesOverflowRow_WhenFiltering_ThenPreviewLimitIsBypassed() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<8).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: index == 6 ? "Needle Result" : "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 5)
        XCTAssertFalse(viewModel.sections.first?.sessions.contains(where: { $0.id == "sessions/6.jsonl" }) ?? true)

        viewModel.searchQuery = "needle"

        try await waitUntil {
            viewModel.sections.count == 1 &&
            viewModel.sections.first?.visibleSessionCount == 1 &&
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/6.jsonl"] &&
            !(viewModel.sections.first?.isExpanded ?? true)
        }
    }

    func testBDD_GivenExpandedSectionWhenSearchClears_WhenFilteringEnds_ThenOriginalExpansionStateIsPreserved() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<8).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: index == 6 ? "Needle Result" : "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        let sectionID = try XCTUnwrap(viewModel.sections.first?.id)
        viewModel.toggleSectionExpansion(sectionID)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 8)
        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)

        viewModel.searchQuery = "needle"
        try await waitUntil {
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/6.jsonl"]
        }

        viewModel.searchQuery = ""
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 8)
        XCTAssertTrue(viewModel.sections.first?.isExpanded ?? false)
    }

    func testBDD_GivenFastTyping_WhenSearchQueryChanges_ThenFilteringWaitsForDebouncedQuery() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<8).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: index == 6 ? "Needle Result" : "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot])),
            preferencesStore: CodexSessionsPreferencesStore(
                providerID: provider.id,
                userDefaults: UserDefaults(suiteName: "CodexSessionsTabViewModelTests.debounce.\(UUID().uuidString)")!
            ),
            searchDebounceNanoseconds: 120_000_000
        )

        await viewModel.load()
        viewModel.searchQuery = "needle"

        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 5)
        XCTAssertFalse(viewModel.sections.first?.sessions.contains(where: { $0.id == "sessions/6.jsonl" }) ?? true)

        try await waitUntil(timeout: 1.0, pollNanoseconds: 20_000_000) {
            viewModel.sections.first?.sessions.map(\.id) == ["sessions/6.jsonl"]
        }
    }

    func testBDD_GivenProviderGrouping_WhenSwitchingGrouping_ThenProviderViewRemainsAvailable() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 900
                ),
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        viewModel.setGroupingMode(.provider)

        XCTAssertEqual(viewModel.groupingMode, .provider)
        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections.map(\.title), ["openai", "anthropic"])
    }

    func testBDD_GivenProviderGroupsHaveDifferentLatestSessionTimes_WhenSwitchingGrouping_ThenSectionsSortByLatestSessionTimeDescending() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/openai-old.jsonl",
                    threadID: "thread-openai-old",
                    title: "OpenAI Old",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
                makeSession(
                    id: "sessions/openai-new.jsonl",
                    threadID: "thread-openai-new",
                    title: "OpenAI New",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 3_000
                ),
                makeSession(
                    id: "sessions/anthropic-newer.jsonl",
                    threadID: "thread-anthropic-newer",
                    title: "Anthropic Newer",
                    modelProvider: "anthropic",
                    cwd: "/tmp/project-beta",
                    updatedAt: 4_000
                ),
                makeSession(
                    id: "sessions/gemini-mid.jsonl",
                    threadID: "thread-gemini-mid",
                    title: "Gemini Mid",
                    modelProvider: "gemini",
                    cwd: "/tmp/project-gamma",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai", "anthropic", "gemini"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        viewModel.setGroupingMode(.provider)

        XCTAssertEqual(viewModel.sections.map(\.title), ["anthropic", "openai", "gemini"])
        XCTAssertEqual(viewModel.sections.map { $0.sessions.first?.id ?? "" }, [
            "sessions/anthropic-newer.jsonl",
            "sessions/openai-new.jsonl",
            "sessions/gemini-mid.jsonl",
        ])
    }

    func testBDD_GivenSessionsCarryRawMetadata_WhenLoading_ThenRowsPreserveForkedFromOriginatorAndSource() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000,
                    forkedFromID: "parent-thread-01",
                    originator: "claude-code",
                    source: "cli"
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()

        let row = try XCTUnwrap(viewModel.sections.first?.sessions.first)
        XCTAssertEqual(row.forkedFromID, "parent-thread-01")
        XCTAssertEqual(row.originator, "claude-code")
        XCTAssertEqual(row.source, "cli")
    }

    func testBDD_GivenLoadedSections_WhenLoadCompletes_ThenNewestVisibleSessionBecomesSelected() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/older.jsonl",
                    threadID: "thread-older",
                    title: "Older",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
                makeSession(
                    id: "sessions/newest.jsonl",
                    threadID: "thread-newest",
                    title: "Newest",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/newest.jsonl")
        XCTAssertEqual(viewModel.selectedSession?.title, "Newest")
    }

    func testBDD_GivenSelectedSessionBecomesCollapsedButStillExists_WhenVisibleRowsRebuild_ThenSelectionIsPreserved() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: Array(0..<8).map { index in
                makeSession(
                    id: "sessions/\(index).jsonl",
                    threadID: "thread-\(index)",
                    title: "Session \(index)",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000 - TimeInterval(index)
                )
            },
            availableProviderIDs: ["openai"]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot]))
        )

        await viewModel.load()
        let sectionID = try XCTUnwrap(viewModel.sections.first?.id)
        viewModel.toggleSectionExpansion(sectionID)
        viewModel.selectSession("sessions/6.jsonl")

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/6.jsonl")
        XCTAssertEqual(viewModel.selectedSession?.id, "sessions/6.jsonl")

        viewModel.toggleSectionExpansion(sectionID)

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/6.jsonl")
        XCTAssertEqual(viewModel.selectedSession?.id, "sessions/6.jsonl")
        XCTAssertEqual(viewModel.sections.first?.sessions.first?.id, "sessions/0.jsonl")
    }

    func testBDD_GivenSelectedSessionDisappearsAfterRefresh_WhenVisibleRowsRebuild_ThenSelectionFallsBackToFirstVisibleSession() async throws {
        let provider = makeCodexProvider()
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_900
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let refreshedSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_100
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [initialSnapshot])
        let service = MockCodexSessionsService(state: state)
        let viewModel = CodexSessionsTabViewModel(provider: provider, service: service)

        await viewModel.load()
        XCTAssertEqual(viewModel.selectedSessionID, "sessions/a.jsonl")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 0)

        state.snapshots = [refreshedSnapshot]
        await viewModel.refresh()

        XCTAssertEqual(viewModel.selectedSessionID, "sessions/b.jsonl")
        XCTAssertEqual(viewModel.selectedSession?.title, "Beta")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 1)
    }

    func testBDD_GivenProjectSkeletonPreload_WhenStreamHasNotYieldedRows_ThenProjectSectionsRenderAsPlaceholders() async throws {
        let provider = makeCodexProvider()
        let state = MockCodexSessionsServiceState(
            snapshots: [
                CodexSessionSnapshot(
                    sessions: [
                        makeSession(
                            id: "sessions/a.jsonl",
                            threadID: "thread-a",
                            title: "Alpha",
                            modelProvider: "openai",
                            cwd: "/tmp/project-alpha",
                            updatedAt: 2_000
                        ),
                    ],
                    availableProviderIDs: ["openai"]
                )
            ],
            skeletonSnapshot: .init(
                projects: [
                    .init(projectPath: "/tmp/project-alpha", liveCount: 1, archivedCount: 0, latestUpdatedAt: Date(timeIntervalSince1970: 2_000)),
                    .init(projectPath: "/tmp/project-beta", liveCount: 2, archivedCount: 1, latestUpdatedAt: Date(timeIntervalSince1970: 1_900)),
                ],
                availableProviderIDs: ["openai", "anthropic"]
            )
        )
        state.initialStreamDelayNanoseconds = 80_000_000

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        let loadTask = Task { await viewModel.load() }
        try await waitUntil {
            viewModel.sections.count == 2 && viewModel.sections.allSatisfy(\.isPlaceholder)
        }

        XCTAssertEqual(viewModel.sections.map(\.title), ["project-alpha", "project-beta"])
        XCTAssertEqual(viewModel.sections.map(\.sessions.count), [0, 0])
        XCTAssertNil(viewModel.selectedSessionID)

        _ = await loadTask.value

        XCTAssertEqual(viewModel.sections.map(\.isPlaceholder), [false, true])
        XCTAssertEqual(viewModel.sections.first?.sessions.map(\.id), ["sessions/a.jsonl"])
        XCTAssertEqual(viewModel.selectedSessionID, "sessions/a.jsonl")
    }

    func testBDD_GivenProjectSkeletonOrder_WhenStreamingBatchesArrive_ThenSectionOrderAndIdentityStayStable() async throws {
        let provider = makeCodexProvider()
        let alphaSession = makeSession(
            id: "sessions/a.jsonl",
            threadID: "thread-a",
            title: "Alpha",
            modelProvider: "openai",
            cwd: "/tmp/project-alpha",
            updatedAt: 3_000
        )
        let betaSession = makeSession(
            id: "sessions/b.jsonl",
            threadID: "thread-b",
            title: "Beta",
            modelProvider: "openai",
            cwd: "/tmp/project-beta",
            updatedAt: 2_000
        )
        let state = MockCodexSessionsServiceState(
            snapshots: [CodexSessionSnapshot(sessions: [alphaSession, betaSession], availableProviderIDs: ["openai"])],
            streamSnapshots: [
                CodexSessionSnapshot(sessions: [betaSession], availableProviderIDs: ["openai"]),
                CodexSessionSnapshot(sessions: [alphaSession, betaSession], availableProviderIDs: ["openai"]),
            ],
            skeletonSnapshot: .init(
                projects: [
                    .init(projectPath: "/tmp/project-alpha", liveCount: 1, archivedCount: 0, latestUpdatedAt: Date(timeIntervalSince1970: 3_000)),
                    .init(projectPath: "/tmp/project-beta", liveCount: 1, archivedCount: 0, latestUpdatedAt: Date(timeIntervalSince1970: 2_000)),
                ],
                availableProviderIDs: ["openai"]
            )
        )
        state.initialStreamDelayNanoseconds = 20_000_000
        state.interSnapshotDelayNanoseconds = 80_000_000

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        let loadTask = Task { await viewModel.load() }
        try await waitUntil {
            viewModel.sections.count == 2 && viewModel.sections.first?.sessions.isEmpty == true
        }
        let placeholderSectionIDs = viewModel.sections.map(\.id)

        try await waitUntil {
            viewModel.sections.count == 2 &&
            viewModel.sections.map(\.id) == placeholderSectionIDs &&
            viewModel.sections.first?.isPlaceholder == true &&
            viewModel.sections.dropFirst().first?.sessions.map(\.id) == ["sessions/b.jsonl"]
        }

        try await waitUntil {
            viewModel.sections.count == 2 &&
            viewModel.sections.first?.id == placeholderSectionIDs.first &&
            viewModel.sections.first?.sessions.first?.id == "sessions/a.jsonl"
        }

        XCTAssertEqual(viewModel.sections.map(\.title), ["project-alpha", "project-beta"])
        XCTAssertEqual(viewModel.sections.map(\.id), placeholderSectionIDs)
        XCTAssertEqual(viewModel.sections.map(\.isPlaceholder), [false, false])

        _ = await loadTask.value
    }

    func testBDD_GivenPersistedGroupingMode_WhenCreatingViewModel_ThenGroupingModeRestoresFromPreferencesStore() async throws {
        let provider = makeCodexProvider()
        let suiteName = "CodexSessionsTabViewModelTests.grouping.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let preferencesStore = CodexSessionsPreferencesStore(
            providerID: provider.id,
            userDefaults: defaults
        )
        preferencesStore.groupingMode = .provider

        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot])),
            preferencesStore: preferencesStore
        )

        XCTAssertEqual(viewModel.groupingMode, .provider)

        await viewModel.load()
        XCTAssertEqual(viewModel.groupingMode, .provider)
    }

    func testBDD_GivenPersistedSortMode_WhenCreatingViewModel_ThenSortModeRestoresFromPreferencesStore() async throws {
        let provider = makeCodexProvider()
        let suiteName = "CodexSessionsTabViewModelTests.sorting.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let preferencesStore = CodexSessionsPreferencesStore(
            providerID: provider.id,
            userDefaults: defaults
        )
        preferencesStore.sortMode = .usage

        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )

        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: [snapshot])),
            preferencesStore: preferencesStore
        )

        XCTAssertEqual(viewModel.sortMode, .usage)

        await viewModel.load()
        XCTAssertEqual(viewModel.sortMode, .usage)
    }

    func testBDD_GivenLoadedSessionsPage_WhenAppBecomesActive_ThenRefreshUsesStableSnapshotReload() async throws {
        let provider = makeCodexProvider()
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let refreshedSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta Latest",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [initialSnapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Alpha")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 0)

        state.snapshots = [refreshedSnapshot]
        await viewModel.refreshOnAppActivationIfNeeded()

        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Beta Latest")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 1)
    }

    func testBDD_GivenLoadedSessionsPage_WhenViewAppearsAfterStaleInterval_ThenRefreshUsesStableSnapshotReload() async throws {
        let provider = makeCodexProvider()
        let clock = MutableDateProvider(now: Date(timeIntervalSince1970: 1_000))
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let refreshedSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta Latest",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [initialSnapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state),
            autoRefreshInterval: 30,
            dateProvider: { clock.now }
        )

        await viewModel.handleViewAppearance()
        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Alpha")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 0)

        state.snapshots = [refreshedSnapshot]
        clock.now = Date(timeIntervalSince1970: 1_031)

        await viewModel.handleViewAppearance()

        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Beta Latest")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 1)
    }

    func testBDD_GivenFreshLoadedSessionsPage_WhenForegroundRefreshTickRuns_ThenRefreshIsSkipped() async throws {
        let provider = makeCodexProvider()
        let clock = MutableDateProvider(now: Date(timeIntervalSince1970: 1_000))
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let refreshedSnapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/b.jsonl",
                    threadID: "thread-b",
                    title: "Beta Latest",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [initialSnapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state),
            autoRefreshInterval: 30,
            dateProvider: { clock.now }
        )

        await viewModel.handleViewAppearance()
        state.snapshots = [refreshedSnapshot]
        clock.now = Date(timeIntervalSince1970: 1_010)

        await viewModel.refreshForForegroundTickIfNeeded()

        XCTAssertEqual(viewModel.sections.first?.sessions.first?.title, "Alpha")
        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 0)
    }

    func testBDD_GivenSessionsNeverLoaded_WhenAppBecomesActive_ThenRefreshIsSkipped() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                )
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.refreshOnAppActivationIfNeeded()

        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertEqual(state.snapshotStreamCallCount, 0)
        XCTAssertEqual(state.loadSnapshotCallCount, 0)
    }

    func testBDD_GivenMatchingStoreWarningNotification_WhenObserved_ThenViewModelPublishesDiagnosticMessage() async throws {
        let provider = makeCodexProvider()
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: []))
        )
        let message = "CodexSessionStore warning for \(provider.codexHomeFolder.url.path)"

        await viewModel.load()

        NotificationCenter.default.post(
            name: CodexSessionStore.warningNotification,
            object: nil,
            userInfo: [
                "message": message,
                "codex_home_path": provider.codexHomeFolder.url.path,
            ]
        )

        try await waitUntil {
            viewModel.diagnosticMessage == message
        }
    }

    func testBDD_GivenMatchingSlowStorePerformanceNotification_WhenObserved_ThenViewModelPublishesAndClearsDiagnosticMessage() async throws {
        let provider = makeCodexProvider()
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: .init(snapshots: []))
        )

        await viewModel.load()

        NotificationCenter.default.post(
            name: CodexSessionStore.performanceNotification,
            object: nil,
            userInfo: [
                "operation": "load_snapshot",
                "elapsed_ms": 2_400,
                "session_count": 42,
                "codex_home_path": provider.codexHomeFolder.url.path,
            ]
        )

        try await waitUntil {
            viewModel.diagnosticMessage?.contains("42") == true
        }

        NotificationCenter.default.post(
            name: CodexSessionStore.performanceNotification,
            object: nil,
            userInfo: [
                "operation": "load_snapshot",
                "elapsed_ms": 120,
                "session_count": 42,
                "codex_home_path": provider.codexHomeFolder.url.path,
            ]
        )

        try await waitUntil {
            viewModel.diagnosticMessage == nil
        }
    }

    func testBDD_GivenSessionsViewModel_WhenLoadIfNeededRunsTwice_ThenSnapshotStreamLoadsOnlyOnce() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/a-1.jsonl",
                    threadID: "thread-a-1",
                    title: "Project Alpha",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 1_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let serviceState = MockCodexSessionsServiceState(snapshots: [snapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        let firstDidLoad = await viewModel.loadIfNeeded()
        let secondDidLoad = await viewModel.loadIfNeeded()

        XCTAssertTrue(firstDidLoad)
        XCTAssertFalse(secondDidLoad)
        XCTAssertEqual(serviceState.snapshotStreamCallCount, 1)
        XCTAssertEqual(viewModel.sections.count, 1)
    }

    func testBDD_GivenInitialSnapshotStreamFailsButSnapshotLoadSucceeds_WhenLoading_ThenViewModelFallsBackToSnapshotRows() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/fallback.jsonl",
                    threadID: "thread-fallback",
                    title: "Fallback Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.snapshotStreamError = NSError(domain: "stream", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "stream failed"
        ])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        await viewModel.load()

        XCTAssertEqual(state.snapshotStreamCallCount, 1)
        XCTAssertEqual(state.loadSnapshotCallCount, 1)
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections.first?.sessions.map(\.id), ["sessions/fallback.jsonl"])
        XCTAssertEqual(viewModel.selectedSessionID, "sessions/fallback.jsonl")
    }

    func testBDD_GivenInitialLoadFails_WhenLoadIfNeededRunsAgain_ThenViewModelRetriesLoading() async throws {
        let provider = makeCodexProvider()
        let snapshot = CodexSessionSnapshot(
            sessions: [
                makeSession(
                    id: "sessions/retry.jsonl",
                    threadID: "thread-retry",
                    title: "Retry Session",
                    modelProvider: "openai",
                    cwd: "/tmp/project-alpha",
                    updatedAt: 2_000
                ),
            ],
            availableProviderIDs: ["openai"]
        )
        let state = MockCodexSessionsServiceState(snapshots: [snapshot])
        state.snapshotStreamError = NSError(domain: "stream", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "stream failed"
        ])
        state.loadSnapshotError = NSError(domain: "snapshot", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "snapshot failed"
        ])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: state)
        )

        let firstDidLoad = await viewModel.loadIfNeeded()

        XCTAssertTrue(firstDidLoad)
        XCTAssertTrue(viewModel.sections.isEmpty)

        state.snapshotStreamError = nil
        state.loadSnapshotError = nil

        let secondDidLoad = await viewModel.loadIfNeeded()

        XCTAssertTrue(secondDidLoad)
        XCTAssertEqual(state.snapshotStreamCallCount, 2)
        XCTAssertEqual(viewModel.sections.first?.sessions.map(\.id), ["sessions/retry.jsonl"])
        XCTAssertEqual(viewModel.selectedSessionID, "sessions/retry.jsonl")
    }

    func testBDD_GivenThreadIDAndWorkingDirectory_WhenBuildingResumeCommand_ThenCommandIsShellSafe() {
        let session = CodexSessionsTabViewModel.SessionRow(
            id: "sessions/refactor.jsonl",
            threadID: "thread-123",
            title: "Refactor",
            summary: nil,
            modelProvider: "openai",
            archived: false,
            rolloutPath: "sessions/refactor.jsonl",
            cwd: "/tmp/project alpha",
            updatedAt: nil,
            stateRowCount: 0,
            editable: true
        )

        let command = CodexSessionsResumeCommandBuilder.commandString(for: session)

        XCTAssertEqual(command, "cd '/tmp/project alpha' && codex resume --last thread-123")
    }

    private func makeCodexProvider() -> Provider {
        Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }

    private func makeSession(
        id: String,
        threadID: String?,
        title: String,
        modelProvider: String,
        cwd: String,
        updatedAt: TimeInterval,
        archived: Bool = false,
        editable: Bool = true,
        forkedFromID: String? = nil,
        originator: String? = nil,
        source: String? = nil
    ) -> CodexSessionRecord {
        .init(
            id: id,
            threadID: threadID,
            title: title,
            summary: "summary-\(title)",
            forkedFromID: forkedFromID,
            originator: originator,
            source: source,
            modelProvider: modelProvider,
            archived: archived,
            rolloutPath: id,
            cwd: cwd,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            stateRowCount: 1,
            editable: editable
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail("Condition did not become true before timeout")
    }
}

private final class MutableDateProvider: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class MockCodexSessionsServiceState: @unchecked Sendable {
    var snapshots: [CodexSessionSnapshot]
    var streamSnapshots: [CodexSessionSnapshot]
    var streamDeltas: [CodexSessionSnapshotDelta]
    var skeletonSnapshot: CodexSessionProjectSkeletonSnapshot?
    let previewResult: Result<CodexSessionRewritePreview, Error>
    let rewriteResult: Result<CodexSessionRewriteResult, Error>
    var previewRequests: [CodexSessionProviderRewriteRequest] = []
    var rewriteRequests: [CodexSessionProviderRewriteRequest] = []
    var rewriteConfirmedPreviews: [CodexSessionRewritePreview?] = []
    var usageResults: [String: Result<CodexSessionTokenTotals?, Error>] = [:]
    var timelineResults: [String: Result<CodexSessionTimeline?, Error>] = [:]
    var usageDelayNanoseconds: UInt64 = 0
    var timelineDelayNanoseconds: UInt64 = 0
    var snapshotDelayNanoseconds: UInt64 = 0
    var initialStreamDelayNanoseconds: UInt64 = 0
    var interSnapshotDelayNanoseconds: UInt64 = 0
    var loadSnapshotError: Error?
    var snapshotStreamError: Error?
    var snapshotStreamCallCount = 0
    var loadSnapshotCallCount = 0
    var preloadCallCount = 0
    var timelineRequests: [String] = []

    init(
        snapshots: [CodexSessionSnapshot],
        streamSnapshots: [CodexSessionSnapshot] = [],
        streamDeltas: [CodexSessionSnapshotDelta] = [],
        skeletonSnapshot: CodexSessionProjectSkeletonSnapshot? = nil,
        previewResult: Result<CodexSessionRewritePreview, Error> = .success(
            .init(sessionCount: 0, liveSessionCount: 0, archivedSessionCount: 0, stateRowCount: 0)
        ),
        rewriteResult: Result<CodexSessionRewriteResult, Error> = .success(
            .init(
                preview: .init(sessionCount: 0, liveSessionCount: 0, archivedSessionCount: 0, stateRowCount: 0),
                liveRolloutFilesUpdated: 0,
                archivedRolloutFilesUpdated: 0,
                stateRowsUpdated: 0,
                failures: []
            )
        )
    ) {
        self.snapshots = snapshots
        self.streamSnapshots = streamSnapshots
        self.streamDeltas = streamDeltas
        self.skeletonSnapshot = skeletonSnapshot
        self.previewResult = previewResult
        self.rewriteResult = rewriteResult
    }
}

private struct MockCodexSessionsService: CodexSessionsTabServicing, CodexSessionsTabStreamingServicing, CodexSessionsTabPreloadingServicing {
    let state: MockCodexSessionsServiceState

    func loadSnapshot(codexHome: URL) throws -> CodexSessionSnapshot {
        _ = codexHome
        state.loadSnapshotCallCount += 1
        if let error = state.loadSnapshotError {
            throw error
        }
        if state.snapshotDelayNanoseconds > 0 {
            Thread.sleep(forTimeInterval: Double(state.snapshotDelayNanoseconds) / 1_000_000_000)
        }
        if state.snapshots.count > 1 {
            return state.snapshots.removeFirst()
        }
        return try XCTUnwrap(state.snapshots.first)
    }

    func loadSessionUsage(
        codexHome: URL,
        rolloutPath: String
    ) throws -> CodexSessionTokenTotals? {
        _ = codexHome
        if state.usageDelayNanoseconds > 0 {
            Thread.sleep(forTimeInterval: Double(state.usageDelayNanoseconds) / 1_000_000_000)
        }
        if let result = state.usageResults[rolloutPath] {
            return try result.get()
        }
        return nil
    }

    func loadSessionTimeline(
        codexHome: URL,
        rolloutPath: String
    ) throws -> CodexSessionTimeline? {
        _ = codexHome
        state.timelineRequests.append(rolloutPath)
        if state.timelineDelayNanoseconds > 0 {
            Thread.sleep(forTimeInterval: Double(state.timelineDelayNanoseconds) / 1_000_000_000)
        }
        if let result = state.timelineResults[rolloutPath] {
            return try result.get()
        }
        return nil
    }

    func previewRewrite(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest
    ) throws -> CodexSessionRewritePreview {
        _ = codexHome
        state.previewRequests.append(request)
        return try state.previewResult.get()
    }

    func rewriteProviders(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest,
        confirmedPreview: CodexSessionRewritePreview?
    ) throws -> CodexSessionRewriteResult {
        _ = codexHome
        state.rewriteRequests.append(request)
        state.rewriteConfirmedPreviews.append(confirmedPreview)
        return try state.rewriteResult.get()
    }

    func loadProjectSkeletonSnapshot(codexHome: URL) throws -> CodexSessionProjectSkeletonSnapshot {
        _ = codexHome
        state.preloadCallCount += 1
        return state.skeletonSnapshot ?? .init(projects: [], availableProviderIDs: [])
    }

    func snapshotStream(
        codexHome: URL,
        batchSize: Int
    ) -> AsyncThrowingStream<CodexSessionSnapshotDelta, Error> {
        _ = codexHome
        _ = batchSize
        state.snapshotStreamCallCount += 1

        return AsyncThrowingStream { continuation in
            Task {
                let deltas: [CodexSessionSnapshotDelta]
                if !state.streamDeltas.isEmpty {
                    deltas = state.streamDeltas
                } else {
                    let snapshots: [CodexSessionSnapshot]
                    if state.streamSnapshots.isEmpty {
                        snapshots = state.snapshots
                    } else {
                        snapshots = state.streamSnapshots
                    }
                    deltas = Self.makeDeltas(from: snapshots)
                }

                for (index, delta) in deltas.enumerated() {
                    if index == 0 && state.initialStreamDelayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: state.initialStreamDelayNanoseconds)
                    }
                    if let error = state.snapshotStreamError {
                        continuation.finish(throwing: error)
                        return
                    }
                    continuation.yield(delta)
                    if index < deltas.count - 1 {
                        let delay = state.interSnapshotDelayNanoseconds > 0
                            ? state.interSnapshotDelayNanoseconds
                            : 50_000_000
                        try? await Task.sleep(nanoseconds: delay)
                    }
                    await Task.yield()
                }
                continuation.finish()
            }
        }
    }

    private static func makeDeltas(from snapshots: [CodexSessionSnapshot]) -> [CodexSessionSnapshotDelta] {
        guard !snapshots.isEmpty else { return [] }
        var previousByID: [String: CodexSessionRecord] = [:]
        var deltas: [CodexSessionSnapshotDelta] = []
        deltas.reserveCapacity(snapshots.count)

        for (index, snapshot) in snapshots.enumerated() {
            var changedSessions: [CodexSessionRecord] = []
            for session in snapshot.sessions {
                if previousByID[session.id] != session {
                    changedSessions.append(session)
                }
                previousByID[session.id] = session
            }
            deltas.append(
                CodexSessionSnapshotDelta(
                    sessions: changedSessions.sorted { lhs, rhs in
                        let leftDate = lhs.updatedAt ?? .distantPast
                        let rightDate = rhs.updatedAt ?? .distantPast
                        if leftDate != rightDate {
                            return leftDate > rightDate
                        }
                        return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
                    },
                    availableProviderIDs: snapshot.availableProviderIDs,
                    isComplete: index == snapshots.count - 1
                )
            )
        }
        return deltas
    }
}

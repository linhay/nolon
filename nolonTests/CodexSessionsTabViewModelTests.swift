import XCTest
import ProviderCatalog
import CodexProvider
import NolonUIFoundation
@testable import nolon

@MainActor
final class CodexSessionsTabViewModelTests: XCTestCase {
    func testBDD_GivenSessionSnapshot_WhenLoading_ThenSectionsAndTargetProvidersAreExposed() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/live-a.jsonl",
                            threadID: "thread-live",
                            title: "Live Session",
                            summary: "hello",
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/live-a.jsonl",
                            cwd: "/tmp/live",
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "archived_sessions/archive-b.jsonl",
                            threadID: "thread-archived",
                            title: "Archived Session",
                            summary: "world",
                            modelProvider: "provider-three",
                            archived: true,
                            rolloutPath: "archived_sessions/archive-b.jsonl",
                            cwd: "/tmp/archive",
                            updatedAt: Date(timeIntervalSince1970: 900),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["provider-two", "provider-three", "openai"]
                ),
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.totalSessionCount, 2)
        XCTAssertEqual(viewModel.totalLiveCount, 1)
        XCTAssertEqual(viewModel.totalArchivedCount, 1)
        XCTAssertEqual(viewModel.availableTargetProviderIDs, ["provider-two", "provider-three", "openai"])
        XCTAssertEqual(viewModel.sections.first?.modelProvider, "provider-two")
        XCTAssertEqual(viewModel.sections.last?.modelProvider, "provider-three")
    }

    func testBDD_GivenManySessions_WhenLoading_ThenOnlyFirstPageIsPublishedUntilLoadingMore() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/1.jsonl",
                            threadID: "thread-1",
                            title: "Session 1",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/2.jsonl",
                            threadID: "thread-2",
                            title: "Session 2",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 999),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/3.jsonl",
                            threadID: "thread-3",
                            title: "Session 3",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: true,
                            rolloutPath: "sessions/3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 998),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["provider-two", "provider-three"]
                )
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState),
            pageSize: 2
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.totalSessionCount, 3)
        XCTAssertEqual(viewModel.visibleSessionCount, 2)
        XCTAssertTrue(viewModel.canLoadMore)
        XCTAssertEqual(viewModel.remainingSessionCount, 1)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 2)
        XCTAssertEqual(viewModel.sections.first?.totalSessionCount, 3)

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.visibleSessionCount, 3)
        XCTAssertFalse(viewModel.canLoadMore)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 3)
    }

    func testBDD_GivenCollapsedSection_WhenLoadingMoreOrRefreshingVisibleSections_ThenCollapseStateDoesNotChangePaginationMetrics() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/1.jsonl",
                            threadID: "thread-1",
                            title: "Session 1",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/2.jsonl",
                            threadID: "thread-2",
                            title: "Session 2",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 999),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/3.jsonl",
                            threadID: "thread-3",
                            title: "Session 3",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: true,
                            rolloutPath: "sessions/3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 998),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["provider-two", "provider-three"]
                )
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState),
            pageSize: 2
        )

        await viewModel.load()

        let firstSectionID = try XCTUnwrap(viewModel.sections.first?.id)
        XCTAssertFalse(viewModel.sections.first?.isCollapsed ?? true)
        XCTAssertEqual(viewModel.visibleSessionCount, 2)

        viewModel.toggleSectionCollapse(firstSectionID)

        XCTAssertTrue(viewModel.sections.first?.isCollapsed == true)
        XCTAssertEqual(viewModel.visibleSessionCount, 2)
        XCTAssertTrue(viewModel.canLoadMore)

        viewModel.loadNextPage()

        XCTAssertTrue(viewModel.sections.first?.isCollapsed == true)
        XCTAssertEqual(viewModel.visibleSessionCount, 3)
        XCTAssertEqual(viewModel.sections.first?.visibleSessionCount, 3)
        XCTAssertFalse(viewModel.canLoadMore)
    }

    func testBDD_GivenMultipleSections_WhenLoadingFirstPage_ThenEachSectionGetsAScreenPresenceBeforeExtraRowsFillThePage() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/1.jsonl",
                            threadID: "thread-1",
                            title: "Session 1",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/2.jsonl",
                            threadID: "thread-2",
                            title: "Session 2",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 999),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/3.jsonl",
                            threadID: "thread-3",
                            title: "Session 3",
                            summary: nil,
                            modelProvider: "provider-three",
                            archived: false,
                            rolloutPath: "sessions/3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 998),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["provider-two", "provider-three"]
                )
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState),
            pageSize: 2
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.visibleSessionCount, 2)
        XCTAssertEqual(viewModel.sections[0].visibleSessionCount, 1)
        XCTAssertEqual(viewModel.sections[1].visibleSessionCount, 1)

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.visibleSessionCount, 3)
        XCTAssertEqual(viewModel.sections[0].visibleSessionCount, 2)
        XCTAssertEqual(viewModel.sections[1].visibleSessionCount, 1)
    }

    func testBDD_GivenSingleSessionRewrite_WhenConfirming_ThenStatusMessageRefreshesFromUpdatedSnapshot() async throws {
        let provider = makeCodexProvider()
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: "hello",
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/live",
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let updatedSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: "hello",
                    modelProvider: "provider-three",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/live",
                    updatedAt: Date(timeIntervalSince1970: 1_100),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [initialSnapshot, updatedSnapshot],
            previewResult: .success(
                .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1)
            ),
            rewriteResult: .success(
                .init(
                    preview: .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1),
                    liveRolloutFilesUpdated: 1,
                    archivedRolloutFilesUpdated: 0,
                    stateRowsUpdated: 1,
                    failures: []
                )
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        let session = try XCTUnwrap(viewModel.sections.first?.sessions.first)

        await viewModel.requestRewrite(for: session, targetProviderID: "provider-three")

        XCTAssertEqual(serviceState.previewRequests.first?.targetProviderID, "provider-three")
        XCTAssertNotNil(viewModel.pendingRewrite)
        XCTAssertNil(viewModel.statusMessage)

        await viewModel.confirmPendingRewrite()

        XCTAssertNil(viewModel.pendingRewrite)
        XCTAssertEqual(serviceState.rewriteRequests.first?.targetProviderID, "provider-three")
        XCTAssertEqual(
            serviceState.rewriteConfirmedPreviews.first,
            .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1)
        )
        XCTAssertTrue(viewModel.statusMessage?.contains("provider-three") == true)
        XCTAssertEqual(viewModel.sections.first?.modelProvider, "provider-three")
    }

    func testBDD_GivenRewriteSucceedsWithConsistencyWarnings_WhenConfirming_ThenWarningStaysInStatusBannerInsteadOfAlert() async throws {
        let provider = makeCodexProvider()
        let initialSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: nil,
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/live",
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let updatedSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: nil,
                    modelProvider: "provider-three",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/live",
                    updatedAt: Date(timeIntervalSince1970: 1_100),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [initialSnapshot, updatedSnapshot],
            previewResult: .success(
                .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1)
            ),
            rewriteResult: .success(
                .init(
                    preview: .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1),
                    liveRolloutFilesUpdated: 1,
                    archivedRolloutFilesUpdated: 0,
                    stateRowsUpdated: 0,
                    failures: ["rewrite verification: state db state_4.sqlite for thread thread-live still points to provider-two, expected provider-three"]
                )
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        let session = try XCTUnwrap(viewModel.sections.first?.sessions.first)

        await viewModel.requestRewrite(for: session, targetProviderID: "provider-three")
        await viewModel.confirmPendingRewrite()

        XCTAssertNil(viewModel.alertMessage)
        XCTAssertTrue(viewModel.statusMessage?.contains("provider-three") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("verification") == true)
    }

    func testBDD_GivenPaginatedSection_WhenRewritingGroup_ThenUsesAllEditableSessionsInThatProvider() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/1.jsonl",
                            threadID: "thread-1",
                            title: "Session 1",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/2.jsonl",
                            threadID: "thread-2",
                            title: "Session 2",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: false,
                            rolloutPath: "sessions/2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 999),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/3.jsonl",
                            threadID: "thread-3",
                            title: "Session 3",
                            summary: nil,
                            modelProvider: "provider-two",
                            archived: true,
                            rolloutPath: "sessions/3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 998),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["provider-two", "provider-three"]
                )
            ],
            previewResult: .success(
                .init(sessionCount: 3, liveSessionCount: 2, archivedSessionCount: 1, stateRowCount: 3)
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState),
            pageSize: 1
        )

        await viewModel.load()
        let section = try XCTUnwrap(viewModel.sections.first)

        XCTAssertEqual(section.visibleSessionCount, 1)
        XCTAssertEqual(section.totalSessionCount, 3)

        await viewModel.requestRewrite(for: section, targetProviderID: "provider-three")

        XCTAssertEqual(
            serviceState.previewRequests.first?.threadIDs.sorted(),
            ["thread-1", "thread-2", "thread-3"]
        )
        XCTAssertEqual(viewModel.pendingRewrite?.preview.sessionCount, 3)
    }

    func testBDD_GivenSectionRewritePreview_WhenReadingConfirmationAlert_ThenSourceAndTargetUseDisplayNamePlusRawID() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/live-a.jsonl",
                            threadID: "thread-live",
                            title: "Live Session",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/live-a.jsonl",
                            cwd: "/tmp/live",
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["openai", "anthropic"]
                )
            ],
            previewResult: .success(
                .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1)
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        let section = try XCTUnwrap(viewModel.sections.first)

        await viewModel.requestRewrite(for: section, targetProviderID: "anthropic")

        XCTAssertTrue(
            viewModel.confirmationAlertData.message.contains("OpenAI (openai)") == true
        )
        XCTAssertTrue(
            viewModel.confirmationAlertData.message.contains("Anthropic (anthropic)") == true
        )
    }

    func testBDD_GivenSingleSessionRewritePreview_WhenReadingConfirmationAlert_ThenSessionTitleAndSourceProviderAreBothVisible() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/live-a.jsonl",
                            threadID: "thread-live",
                            title: "Investigate rollout drift",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/live-a.jsonl",
                            cwd: "/tmp/live",
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["openai", "anthropic"]
                )
            ],
            previewResult: .success(
                .init(sessionCount: 1, liveSessionCount: 1, archivedSessionCount: 0, stateRowCount: 1)
            )
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        let session = try XCTUnwrap(viewModel.sections.first?.sessions.first)

        await viewModel.requestRewrite(for: session, targetProviderID: "anthropic")

        XCTAssertTrue(
            viewModel.confirmationAlertData.message.contains("Investigate rollout drift") == true
        )
        XCTAssertTrue(
            viewModel.confirmationAlertData.message.contains("OpenAI (openai)") == true
        )
        XCTAssertTrue(
            viewModel.confirmationAlertData.message.contains("Anthropic (anthropic)") == true
        )
    }

    func testBDD_GivenStreamingSnapshots_WhenLoading_ThenPublishesFirstBatchBeforeFinalSnapshot() async throws {
        let provider = makeCodexProvider()
        let firstSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/1.jsonl",
                    threadID: "thread-1",
                    title: "Session 1",
                    summary: "hello",
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/1.jsonl",
                    cwd: nil,
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let finalSnapshot = CodexSessionSnapshot(
            sessions: firstSnapshot.sessions + [
                .init(
                    id: "sessions/2.jsonl",
                    threadID: "thread-2",
                    title: "Session 2",
                    summary: "world",
                    modelProvider: "provider-three",
                    archived: true,
                    rolloutPath: "sessions/2.jsonl",
                    cwd: nil,
                    updatedAt: Date(timeIntervalSince1970: 999),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [finalSnapshot],
            streamSnapshots: [firstSnapshot, finalSnapshot]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        let loadTask = Task { await viewModel.load() }

        await fulfillment(of: [serviceState.firstStreamSnapshotDelivered], timeout: 1.0)
        XCTAssertEqual(viewModel.totalSessionCount, 1)
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertFalse(viewModel.showsInitialSkeleton)

        _ = await loadTask.value

        XCTAssertEqual(viewModel.totalSessionCount, 2)
        XCTAssertEqual(viewModel.sections.count, 2)
    }

    func testBDD_GivenStreamingLoad_WhenViewModelPublishesPerformanceMetrics_ThenFirstSnapshotAndFullLoadMetricsAreBothEmitted() async throws {
        let provider = makeCodexProvider()
        let firstSnapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/1.jsonl",
                    threadID: "thread-1",
                    title: "Session 1",
                    summary: nil,
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/1.jsonl",
                    cwd: nil,
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let finalSnapshot = CodexSessionSnapshot(
            sessions: firstSnapshot.sessions + [
                .init(
                    id: "sessions/2.jsonl",
                    threadID: "thread-2",
                    title: "Session 2",
                    summary: nil,
                    modelProvider: "provider-three",
                    archived: false,
                    rolloutPath: "sessions/2.jsonl",
                    cwd: nil,
                    updatedAt: Date(timeIntervalSince1970: 999),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["provider-two", "provider-three"]
        )
        let recorder = ViewModelPerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionsTabViewModel.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let serviceState = MockCodexSessionsServiceState(
            snapshots: [finalSnapshot],
            streamSnapshots: [firstSnapshot, finalSnapshot]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()

        let firstMetrics = try XCTUnwrap(recorder.payloads.first(where: { ($0["operation"] as? String) == "load_first_snapshot" }))
        XCTAssertEqual(firstMetrics["provider_id"] as? String, "codex")
        XCTAssertEqual(firstMetrics["session_count"] as? Int, 1)
        XCTAssertGreaterThanOrEqual(firstMetrics["elapsed_ms"] as? Int ?? -1, 0)

        let completeMetrics = try XCTUnwrap(recorder.payloads.first(where: { ($0["operation"] as? String) == "load_complete" }))
        XCTAssertEqual(completeMetrics["session_count"] as? Int, 2)
        XCTAssertEqual(completeMetrics["visible_session_count"] as? Int, 2)
        XCTAssertEqual(completeMetrics["grouping_mode"] as? String, "provider")
    }

    func testBDD_GivenSessionsShareDayAndProject_WhenSwitchingGrouping_ThenGroupsByTimeAndProject() async throws {
        let provider = makeCodexProvider()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let sameDayFirstDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 15, minute: 30))
        )
        let sameDaySecondDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 14, minute: 45))
        )
        let snapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/1.jsonl",
                    threadID: "thread-1",
                    title: "Session 1",
                    summary: nil,
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/1.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: sameDayFirstDate,
                    stateRowCount: 1,
                    editable: true
                ),
                .init(
                    id: "sessions/2.jsonl",
                    threadID: "thread-2",
                    title: "Session 2",
                    summary: nil,
                    modelProvider: "provider-three",
                    archived: true,
                    rolloutPath: "sessions/2.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: sameDaySecondDate,
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            availableProviderIDs: ["provider-two", "provider-three", "openai"]
        )
        let serviceState = MockCodexSessionsServiceState(snapshots: [snapshot])
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        viewModel.setGroupingMode(.timeProject)

        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections.first?.providerCount, 2)
        XCTAssertEqual(viewModel.sections.first?.editableThreadIDs, [])
        XCTAssertTrue(viewModel.sections.first?.title.contains("project-alpha") == true)
    }

    func testBDD_GivenManyRowsAcrossSections_WhenLoadingFirstPage_ThenEachSectionGetsTwoRowsBeforeExtraRowsAreAssigned() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/openai-1.jsonl",
                            threadID: "thread-openai-1",
                            title: "OpenAI Session 1",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/openai-1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/openai-2.jsonl",
                            threadID: "thread-openai-2",
                            title: "OpenAI Session 2",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/openai-2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 999),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/openai-3.jsonl",
                            threadID: "thread-openai-3",
                            title: "OpenAI Session 3",
                            summary: nil,
                            modelProvider: "openai",
                            archived: true,
                            rolloutPath: "sessions/openai-3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 998),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/anthropic-1.jsonl",
                            threadID: "thread-anthropic-1",
                            title: "Anthropic Session 1",
                            summary: nil,
                            modelProvider: "anthropic",
                            archived: false,
                            rolloutPath: "sessions/anthropic-1.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 997),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/anthropic-2.jsonl",
                            threadID: "thread-anthropic-2",
                            title: "Anthropic Session 2",
                            summary: nil,
                            modelProvider: "anthropic",
                            archived: false,
                            rolloutPath: "sessions/anthropic-2.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 996),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/anthropic-3.jsonl",
                            threadID: "thread-anthropic-3",
                            title: "Anthropic Session 3",
                            summary: nil,
                            modelProvider: "anthropic",
                            archived: true,
                            rolloutPath: "sessions/anthropic-3.jsonl",
                            cwd: nil,
                            updatedAt: Date(timeIntervalSince1970: 995),
                            stateRowCount: 1,
                            editable: true
                        ),
                    ],
                    availableProviderIDs: ["openai", "anthropic"]
                )
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState),
            pageSize: 4
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.visibleSessionCount, 4)
        XCTAssertEqual(viewModel.sections[0].visibleSessionCount, 2)
        XCTAssertEqual(viewModel.sections[1].visibleSessionCount, 2)
    }

    func testBDD_GivenMixedSectionStates_WhenLoading_ThenOverviewMetricsExposeDecisionCounts() async throws {
        let provider = makeCodexProvider()
        let serviceState = MockCodexSessionsServiceState(
            snapshots: [
                .init(
                    sessions: [
                        .init(
                            id: "sessions/openai-live.jsonl",
                            threadID: "thread-openai",
                            title: "OpenAI Session",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/openai-live.jsonl",
                            cwd: "/tmp/project-alpha",
                            updatedAt: Date(timeIntervalSince1970: 1_000),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/mixed-openai.jsonl",
                            threadID: "thread-mixed-openai",
                            title: "Mixed Group OpenAI",
                            summary: nil,
                            modelProvider: "openai",
                            archived: false,
                            rolloutPath: "sessions/mixed-openai.jsonl",
                            cwd: "/tmp/project-beta",
                            updatedAt: Date(timeIntervalSince1970: 900),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "sessions/mixed-custom.jsonl",
                            threadID: "thread-mixed-custom",
                            title: "Mixed Group Custom",
                            summary: nil,
                            modelProvider: "custom-relay",
                            archived: true,
                            rolloutPath: "sessions/mixed-custom.jsonl",
                            cwd: "/tmp/project-beta",
                            updatedAt: Date(timeIntervalSince1970: 899),
                            stateRowCount: 1,
                            editable: true
                        ),
                        .init(
                            id: "archived_sessions/read-only.jsonl",
                            threadID: nil,
                            title: "Read Only Archive",
                            summary: nil,
                            modelProvider: "anthropic",
                            archived: true,
                            rolloutPath: "archived_sessions/read-only.jsonl",
                            cwd: "/tmp/project-gamma",
                            updatedAt: Date(timeIntervalSince1970: 800),
                            stateRowCount: 1,
                            editable: false
                        ),
                    ],
                    availableProviderIDs: ["openai", "anthropic", "custom-relay"]
                )
            ]
        )
        let viewModel = CodexSessionsTabViewModel(
            provider: provider,
            service: MockCodexSessionsService(state: serviceState)
        )

        await viewModel.load()
        viewModel.setGroupingMode(.timeProject)

        XCTAssertEqual(viewModel.groupCount, 3)
        XCTAssertEqual(viewModel.rewritableGroupCount, 1)
        XCTAssertEqual(viewModel.needsAttentionGroupCount, 2)
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
}

private final class MockCodexSessionsServiceState: @unchecked Sendable {
    var snapshots: [CodexSessionSnapshot]
    let streamSnapshots: [CodexSessionSnapshot]
    let previewResult: Result<CodexSessionRewritePreview, Error>
    let rewriteResult: Result<CodexSessionRewriteResult, Error>
    var previewRequests: [CodexSessionProviderRewriteRequest] = []
    var rewriteRequests: [CodexSessionProviderRewriteRequest] = []
    var rewriteConfirmedPreviews: [CodexSessionRewritePreview?] = []
    let firstStreamSnapshotDelivered = XCTestExpectation(description: "first stream snapshot delivered")
    private(set) var hasFulfilledFirstStreamSnapshot = false

    init(
        snapshots: [CodexSessionSnapshot],
        streamSnapshots: [CodexSessionSnapshot] = [],
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
        self.previewResult = previewResult
        self.rewriteResult = rewriteResult
    }

    func markFirstStreamSnapshotDeliveredIfNeeded() {
        guard !hasFulfilledFirstStreamSnapshot else { return }
        hasFulfilledFirstStreamSnapshot = true
        firstStreamSnapshotDelivered.fulfill()
    }
}

private struct MockCodexSessionsService: CodexSessionsTabServicing, CodexSessionsTabStreamingServicing {
    let state: MockCodexSessionsServiceState

    func loadSnapshot(codexHome: URL) throws -> CodexSessionSnapshot {
        _ = codexHome
        if state.snapshots.count > 1 {
            return state.snapshots.removeFirst()
        }
        return try XCTUnwrap(state.snapshots.first)
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

    func snapshotStream(
        codexHome: URL,
        batchSize: Int
    ) -> AsyncThrowingStream<CodexSessionSnapshot, Error> {
        _ = codexHome
        _ = batchSize

        return AsyncThrowingStream { continuation in
            Task {
                let snapshots: [CodexSessionSnapshot]
                if state.streamSnapshots.isEmpty {
                    if state.snapshots.count > 1 {
                        snapshots = [state.snapshots.removeFirst()]
                    } else if let snapshot = state.snapshots.first {
                        snapshots = [snapshot]
                    } else {
                        snapshots = []
                    }
                } else {
                    snapshots = state.streamSnapshots
                }

                for (index, snapshot) in snapshots.enumerated() {
                    continuation.yield(snapshot)
                    if index == 0 {
                        state.markFirstStreamSnapshotDeliveredIfNeeded()
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    await Task.yield()
                }
                continuation.finish()
            }
        }
    }
}

private final class ViewModelPerformanceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var payloads: [[AnyHashable: Any]] = []

    func append(_ payload: [AnyHashable: Any]) {
        lock.lock()
        payloads.append(payload)
        lock.unlock()
    }
}

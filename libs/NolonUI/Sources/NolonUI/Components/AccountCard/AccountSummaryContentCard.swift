import SwiftUI
import NolonUIFoundation

private enum AccountSummaryContentCardLayout {
    static let cardSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
}

public struct AccountSummaryContentCard<Body: View, Details: View, Actions: View>: View {
    private let presentation: AccountCardPresentation
    private let header: AccountSummaryCardHeaderModel
    private let showsDetailsSection: Bool
    private let showsActionsSection: Bool
    @ViewBuilder private var bodyContent: Body
    @ViewBuilder private var detailsContent: Details
    @ViewBuilder private var actionsContent: Actions

    public init(
        presentation: AccountCardPresentation = .neutral,
        header: AccountSummaryCardHeaderModel,
        showsDetailsSection: Bool = false,
        showsActionsSection: Bool = false,
        @ViewBuilder body: () -> Body,
        @ViewBuilder details: () -> Details = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.presentation = presentation
        self.header = header
        self.showsDetailsSection = showsDetailsSection
        self.showsActionsSection = showsActionsSection
        self.bodyContent = body()
        self.detailsContent = details()
        self.actionsContent = actions()
    }

    public var body: some View {
        AccountSummaryCard(presentation: presentation) {
            VStack(alignment: .leading, spacing: AccountSummaryContentCardLayout.cardSpacing) {
                headerSection
                bodySection

                if showsDetailsSection {
                    supplementarySection(detailsContent)
                }

                if showsActionsSection {
                    supplementarySection(actionsContent)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow = header.eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textCase(.uppercase)
                }

                Text(header.title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(1)
                    .layoutPriority(2)

                if let subtitle = header.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if header.badge != nil || (header.meta?.isEmpty == false) {
                VStack(alignment: .trailing, spacing: 6) {
                    if let badge = header.badge {
                        AccountSummaryCardBadge(badge: badge)
                    }

                    if let meta = header.meta, !meta.isEmpty {
                        Text(meta)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var bodySection: some View {
        bodyContent
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supplementarySection<Content: View>(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: AccountSummaryContentCardLayout.sectionSpacing) {
            sectionDivider
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.Component.border.opacity(0.35))
            .frame(height: 1)
    }
}

private struct AccountSummaryCardBadge: View {
    let badge: AccountSummaryCardBadgeModel

    var body: some View {
        Text(badge.text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Component.controlFillSubtle
        case .active:
            return DesignSystem.Colors.primary.opacity(0.2)
        case .warning:
            return DesignSystem.Colors.Status.warning.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .active:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}

@MainActor
private struct AccountSummaryContentCardPreviewContainer: View {
    enum Scene {
        case unifiedPage
        case all
        case codexGeminiAccounts
        case listMode
        case listGrouped
        case gatewayCard
        case gatewayList
        case usageChart
        case healthy
        case lowQuota
        case error
        case loading
        case empty
        case enterprise
    }

    private let scene: Scene

    init(scene: Scene = .all) {
        self.scene = scene
    }

    var body: some View {
        switch scene {
        case .unifiedPage:
            ScrollView {
                unifiedPageScene
            }
            .padding(PreviewLayoutTokens.Spacing.page)
            .background(DesignSystem.Colors.Background.canvas)
        case .all:
            ScrollView {
                allStatesScene
            }
            .padding(PreviewLayoutTokens.Spacing.page)
            .background(DesignSystem.Colors.Background.canvas)
        case .codexGeminiAccounts:
            singleSceneCanvas { codexGeminiAccountsScene }
        case .listMode:
            singleSceneCanvas { listModeScene }
        case .listGrouped:
            singleSceneCanvas { listGroupedScene }
        case .gatewayCard:
            singleSceneCanvas { gatewayCardScene }
        case .gatewayList:
            singleSceneCanvas { gatewayListScene }
        case .usageChart:
            singleSceneCanvas { usageChartScene }
        case .healthy:
            singleSceneCanvas { healthyQuotaScene }
        case .lowQuota:
            singleSceneCanvas { lowQuotaScene }
        case .error:
            singleSceneCanvas { errorScene }
        case .loading:
            singleSceneCanvas { loadingScene }
        case .empty:
            singleSceneCanvas { emptyScene }
        case .enterprise:
            singleSceneCanvas { enterpriseScene }
        }
    }

    private var unifiedPageScene: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.section) {
            Text("Unified Account Workspace")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            codexGeminiAccountsScene
            gatewayListScene
            usageChartScene
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var allStatesScene: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.section) {
            unifiedPageScene
            listGroupedScene
            healthyQuotaScene
            lowQuotaScene
            errorScene
            loadingScene
            emptyScene
            enterpriseScene
            gatewayCardScene
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codexGeminiAccountsScene: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            Text("Realistic Codex & Gemini Accounts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
                previewScene(
                    title: "Codex Account (Active)",
                    presentation: .active,
                    header: .init(
                        eyebrow: "Codex",
                        title: "dzurillaisadore@gmail.com",
                        subtitle: "Pro plan • US region",
                        meta: "Updated 2026-03-21 01:22",
                        badge: .init(text: "ACTIVE", tone: .active)
                    ),
                    showsDetailsSection: false,
                    showsActionsSection: false,
                    body: {
                        quotaBody(
                            rows: [
                                .init(title: "Session", remainingText: "73%", progress: 0.73, meta: "resets in 1h 42m"),
                                .init(title: "Weekly", remainingText: "61%", progress: 0.61, meta: "resets in 2d")
                            ],
                            creditsText: "1,180"
                        )
                    }
                )

                previewScene(
                    title: "Gemini Account (Low Quota)",
                    presentation: .pending,
                    header: .init(
                        eyebrow: "Gemini",
                        title: "gemini.team.alpha@gmail.com",
                        subtitle: "Starter plan • APAC",
                        meta: "Updated 2026-03-21 01:16",
                        badge: .init(text: "WARNING", tone: .warning)
                    ),
                    showsDetailsSection: true,
                    showsActionsSection: false,
                    body: {
                        quotaBody(
                            rows: [
                                .init(title: "Session", remainingText: "12%", progress: 0.12, meta: "resets in 48m"),
                                .init(title: "Daily", remainingText: "19%", progress: 0.19, meta: "resets in 10h")
                            ],
                            creditsText: "42"
                        )
                    },
                    details: {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow(title: "Sync", value: "rate-limited retry policy enabled")
                        }
                    }
                )
            }
            .padding(PreviewLayoutTokens.Spacing.group)
            .background(DesignSystem.Colors.Background.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func singleSceneCanvas<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.section) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PreviewLayoutTokens.Spacing.page)
        .background(DesignSystem.Colors.Background.canvas)
    }

    private var healthyQuotaScene: some View {
        previewScene(
            title: "Healthy Quota / Full Sections",
            presentation: .active,
            header: .init(
                eyebrow: "Codex",
                title: "dzurillaisadore@gmail.com",
                subtitle: "Pro plan",
                meta: "Updated 2026-03-16 22:59",
                badge: .init(text: "ACTIVE", tone: .active)
            ),
            showsDetailsSection: false,
            showsActionsSection: false,
            body: {
                quotaBody(
                    rows: [
                        .init(title: "Session", remainingText: "78%", progress: 0.78, meta: "resets in 2h"),
                        .init(title: "Weekly", remainingText: "64%", progress: 0.64, meta: "resets in 2d")
                    ],
                    creditsText: "1,240"
                )
            }
        )
    }

    private var listModeScene: some View {
        AccountListModeModule(
            items: [
                .init(
                    presentation: .active,
                    header: .init(
                        eyebrow: "Codex",
                        title: "primary@flowup.dev",
                        subtitle: "Pro",
                        meta: "Active",
                        badge: .init(text: "ACTIVE", tone: .active)
                    ),
                    usageWindows: [
                        .init(title: "Session", progress: 0.72, percentText: "72%"),
                        .init(title: "Weekly", progress: 0.61, percentText: "61%")
                    ]
                ),
                .init(
                    presentation: .pending,
                    header: .init(
                        eyebrow: "Claude",
                        title: "backup@flowup.dev",
                        subtitle: "Pro",
                        meta: "Low quota",
                        badge: .init(text: "WARNING", tone: .warning)
                    ),
                    usageWindows: [
                        .init(title: "Session", progress: 0.14, percentText: "14%"),
                        .init(title: "Weekly", progress: 0.18, percentText: "18%")
                    ]
                ),
                .init(
                    presentation: .neutral,
                    header: .init(
                        eyebrow: "Gemini",
                        title: "staging@flowup.dev",
                        subtitle: "Starter",
                        meta: "Sync failed",
                        badge: .init(text: "RETRY", tone: .warning)
                    ),
                    usageWindows: [
                        .init(title: "Session", progress: 0.0, percentText: "--"),
                        .init(title: "Daily", progress: 0.0, percentText: "--")
                    ]
                ),
                .init(
                    presentation: .neutral,
                    header: .init(
                        eyebrow: "OpenAI",
                        title: "new-account@flowup.dev",
                        subtitle: "Syncing",
                        meta: "Loading",
                        badge: .init(text: "SYNCING", tone: .neutral)
                    ),
                    usageWindows: [
                        .init(title: "Session", progress: 0.0, percentText: "..."),
                        .init(title: "Daily", progress: 0.0, percentText: "...")
                    ],
                    isLoadingPlaceholder: true
                )
            ]
        )
    }

    private var listGroupedScene: some View {
        AccountListModeModule(
            title: "Account List (Grouped)",
            sections: [
                .init(
                    title: "Original Vendors",
                    items: [
                        .init(
                            presentation: .active,
                            header: .init(
                                eyebrow: "Codex",
                                title: "primary@flowup.dev",
                                subtitle: "Pro",
                                meta: "Active",
                                badge: .init(text: "ACTIVE", tone: .active)
                            ),
                            usageWindows: [
                                .init(title: "Session", progress: 0.72, percentText: "72%"),
                                .init(title: "Weekly", progress: 0.61, percentText: "61%")
                            ]
                        ),
                        .init(
                            presentation: .pending,
                            header: .init(
                                eyebrow: "Claude",
                                title: "backup@flowup.dev",
                                subtitle: "Pro",
                                meta: "Low quota",
                                badge: .init(text: "WARNING", tone: .warning)
                            ),
                            usageWindows: [
                                .init(title: "Session", progress: 0.14, percentText: "14%"),
                                .init(title: "Weekly", progress: 0.18, percentText: "18%")
                            ]
                        )
                    ]
                ),
                .init(
                    title: "Integrated Vendors",
                    items: [
                        .init(
                            presentation: .neutral,
                            header: .init(
                                eyebrow: "Gemini",
                                title: "staging@flowup.dev",
                                subtitle: "Starter",
                                meta: "Sync failed",
                                badge: .init(text: "RETRY", tone: .warning)
                            ),
                            usageWindows: [
                                .init(title: "Session", progress: 0.0, percentText: "--"),
                                .init(title: "Daily", progress: 0.0, percentText: "--")
                            ]
                        ),
                        .init(
                            presentation: .neutral,
                            header: .init(
                                eyebrow: "OpenAI",
                                title: "new-account@flowup.dev",
                                subtitle: "Syncing",
                                meta: "Loading",
                                badge: .init(text: "SYNCING", tone: .neutral)
                            ),
                            usageWindows: [
                                .init(title: "Session", progress: 0.0, percentText: "..."),
                                .init(title: "Daily", progress: 0.0, percentText: "...")
                            ],
                            isLoadingPlaceholder: true
                        )
                    ]
                )
            ]
        )
    }

    private struct GatewayPreviewMember: Identifiable {
        let id = UUID()
        let name: String
    }

    private var gatewayCardScene: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            Text("Gateway Card")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            gatewayCard(
                name: "Gateway Alpha",
                subtitle: "4 members",
                members: [
                    .init(name: "primary@flowup.dev"),
                    .init(name: "backup@flowup.dev"),
                    .init(name: "staging@flowup.dev"),
                    .init(name: "qa@flowup.dev")
                ],
                presentation: .selected,
                compact: false
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gatewayListScene: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            Text("Gateway List Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
                gatewayCard(
                    name: "Gateway Alpha",
                    subtitle: "3 members",
                    members: [
                        .init(name: "primary@flowup.dev"),
                        .init(name: "backup@flowup.dev"),
                        .init(name: "staging@flowup.dev")
                    ],
                    presentation: .selected,
                    compact: true
                )
                gatewayCard(
                    name: "Gateway Beta",
                    subtitle: "2 members",
                    members: [
                        .init(name: "team-a@flowup.dev"),
                        .init(name: "team-b@flowup.dev")
                    ],
                    presentation: .neutral,
                    compact: true
                )
                gatewayCard(
                    name: "Gateway Gamma",
                    subtitle: "Syncing",
                    members: [
                        .init(name: "new@flowup.dev")
                    ],
                    presentation: .pending,
                    compact: true
                )
                .redacted(reason: .placeholder)
            }
            .padding(PreviewLayoutTokens.Spacing.group)
            .background(DesignSystem.Colors.Background.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gatewayCard(
        name: String,
        subtitle: String,
        members: [GatewayPreviewMember],
        presentation: AccountCardPresentation,
        compact: Bool
    ) -> some View {
        let avatarSize: CGFloat = compact ? 16 : 20
        let chipSpacing: CGFloat = compact ? 4 : 6
        let chipVerticalPadding: CGFloat = compact ? 1 : 2

        return AccountSummaryCard(presentation: presentation) {
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                HStack(spacing: compact ? 8 : 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.15))
                            .frame(width: compact ? 20 : 28, height: compact ? 20 : 28)
                            .offset(x: compact ? 2 : 3, y: compact ? -2 : -3)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: compact ? 20 : 28, height: compact ? 20 : 28)
                            .overlay(
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: compact ? 10 : 14))
                                    .foregroundStyle(.white)
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: compact ? 13 : 14, weight: compact ? .semibold : .bold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(subtitle)
                            .font(.system(size: compact ? 9 : 10, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    Button {} label: {
                        Label("Add Accounts", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(compact ? .mini : .small)

                    Spacer(minLength: 0)
                }

                FlowLayout(spacing: chipSpacing) {
                    ForEach(members.prefix(compact ? 3 : 4)) { member in
                        HStack(spacing: compact ? 3 : 4) {
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.system(size: compact ? 8 : 9, weight: .bold))
                                .frame(width: avatarSize, height: avatarSize)
                                .background(DesignSystem.Colors.primary.opacity(0.12))
                                .foregroundStyle(DesignSystem.Colors.primary)
                                .clipShape(Circle())

                            Text(member.name)
                                .font(.system(size: compact ? 9 : 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .lineLimit(1)
                        }
                        .padding(.leading, 2)
                        .padding(.trailing, compact ? 4 : 6)
                        .padding(.vertical, chipVerticalPadding)
                        .background(DesignSystem.Colors.Background.surface.opacity(0.5))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                }
                .frame(maxHeight: compact ? 24 : 32, alignment: .topLeading)
                .clipped()
            }
        }
    }

    private var usageChartScene: some View {
        AccountUsageContentCardScene()
    }

    private var lowQuotaScene: some View {
        previewScene(
            title: "Low Quota / Warning Badge",
            presentation: .pending,
            header: .init(
                eyebrow: "Claude",
                title: "service@flowup.dev",
                subtitle: "Pro plan",
                meta: "Updated 2026-03-17 08:21",
                badge: .init(text: "WARNING", tone: .warning)
            ),
            showsDetailsSection: true,
            showsActionsSection: false,
            body: {
                quotaBody(
                    rows: [
                        .init(title: "Session", remainingText: "9%", progress: 0.09, meta: "resets in 52m"),
                        .init(title: "Weekly", remainingText: "18%", progress: 0.18, meta: "resets tomorrow")
                    ],
                    creditsText: "35"
                )
            },
            details: {
                detailRow(title: "Reason", value: "Approaching plan quota limits")
            }
        )
    }

    private var errorScene: some View {
        previewScene(
            title: "Error / Quota Fetch Failed",
            presentation: .neutral,
            header: .init(
                eyebrow: "Gemini",
                title: "staging-account@flowup.dev",
                subtitle: "Starter plan",
                meta: "Failed 2m ago",
                badge: .init(text: "WARNING", tone: .warning)
            ),
            showsDetailsSection: false,
            showsActionsSection: false,
            body: {
                AccountErrorStateModule(message: "Rate service timeout. Retry after a short delay.")
            }
        )
    }

    private var loadingScene: some View {
        previewScene(
            title: "Loading / Skeleton",
            presentation: .neutral,
            header: .init(
                eyebrow: "OpenAI",
                title: "loading-account@flowup.dev",
                subtitle: "Syncing usage…",
                meta: "Just now",
                badge: .init(text: "SYNCING", tone: .neutral)
            ),
            showsDetailsSection: false,
            showsActionsSection: false,
            body: {
                AccountLoadingStateModule()
            }
        )
    }

    private var emptyScene: some View {
        previewScene(
            title: "Empty / No Usage Data",
            presentation: .neutral,
            header: .init(
                eyebrow: nil,
                title: "new-account@flowup.dev",
                subtitle: "No quota history yet",
                meta: nil,
                badge: nil
            ),
            showsDetailsSection: false,
            showsActionsSection: false,
            body: {
                AccountEmptyStateModule(text: "No quota data available yet.")
            }
        )
    }

    private var enterpriseScene: some View {
        previewScene(
            title: "Enterprise / Unlimited",
            presentation: .active,
            header: .init(
                eyebrow: "Codex",
                title: "enterprise-admin@flowup.dev",
                subtitle: "Enterprise",
                meta: "Updated moments ago",
                badge: .init(text: "ACTIVE", tone: .active)
            ),
            showsDetailsSection: true,
            showsActionsSection: false,
            body: {
                quotaBody(
                    rows: [
                        .init(title: "Session", remainingText: "∞", progress: 1.0, meta: "no session cap"),
                        .init(title: "Weekly", remainingText: "∞", progress: 1.0, meta: "no weekly cap")
                    ],
                    creditsText: "∞"
                )
            },
            details: {
                detailRow(title: "Policy", value: "Unlimited usage enabled")
            }
        )
    }

    private func previewScene<BodyContent: View, Details: View, Actions: View>(
        title: String,
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        showsDetailsSection: Bool,
        showsActionsSection: Bool,
        @ViewBuilder body: () -> BodyContent,
        @ViewBuilder details: () -> Details = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            AccountSummaryContentCard(
                presentation: presentation,
                header: header,
                showsDetailsSection: showsDetailsSection,
                showsActionsSection: showsActionsSection
            ) {
                body()
            } details: {
                details()
            } actions: {
                actions()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quotaBody(rows: [AccountQuotaRow], creditsText: String) -> some View {
        AccountQuotaModule(rows: rows, creditsText: creditsText)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }
}

@MainActor
private struct AccountSummaryContentCardPreviewScene: View {
    let scene: AccountSummaryContentCardPreviewContainer.Scene

    var body: some View {
        ScrollView(.vertical) {
            AccountSummaryContentCardPreviewContainer(scene: scene)
                .frame(width: preferredWidth, height: preferredHeight, alignment: .topLeading)
        }
        .frame(width: preferredWidth, height: preferredHeight, alignment: .topLeading)
    }

    private var preferredWidth: CGFloat {
        switch scene {
        case .all, .unifiedPage:
            return 760
        case .codexGeminiAccounts:
            return 740
        case .listMode, .listGrouped, .gatewayList:
            return 740
        case .gatewayCard:
            return 720
        case .usageChart:
            return 740
        case .healthy, .lowQuota, .error, .loading, .empty, .enterprise:
            return 720
        }
    }

    private var preferredHeight: CGFloat {
        switch scene {
        case .all:
            return 9800
        case .unifiedPage:
            return 4440
        case .codexGeminiAccounts:
            return 3540
        case .listMode, .listGrouped, .gatewayList:
            return 3480
        case .gatewayCard:
            return 2760
        case .usageChart:
            return 2940
        case .healthy, .lowQuota, .error, .loading, .empty, .enterprise:
            return 2760
        }
    }
}

#Preview("Account Card / All") {
    AccountSummaryContentCardPreviewScene(scene: .all)
}

#Preview("Account Card / Unified") {
    AccountSummaryContentCardPreviewScene(scene: .unifiedPage)
}

#Preview("Account Card / Codex+Gemini") {
    AccountSummaryContentCardPreviewScene(scene: .codexGeminiAccounts)
}

#Preview("Account Card / List") {
    AccountSummaryContentCardPreviewScene(scene: .listMode)
}

#Preview("Account Card / List Grouped") {
    AccountSummaryContentCardPreviewScene(scene: .listGrouped)
}

#Preview("Account Card / Gateway") {
    AccountSummaryContentCardPreviewScene(scene: .gatewayCard)
}

#Preview("Account Card / Gateway List") {
    AccountSummaryContentCardPreviewScene(scene: .gatewayList)
}

#Preview("Account Card / Healthy") {
    AccountSummaryContentCardPreviewScene(scene: .healthy)
}

#Preview("Account Card / Low Quota") {
    AccountSummaryContentCardPreviewScene(scene: .lowQuota)
}

#Preview("Account Card / Error") {
    AccountSummaryContentCardPreviewScene(scene: .error)
}

#Preview("Account Card / Loading") {
    AccountSummaryContentCardPreviewScene(scene: .loading)
}

#Preview("Account Card / Empty") {
    AccountSummaryContentCardPreviewScene(scene: .empty)
}

#Preview("Account Card / Enterprise") {
    AccountSummaryContentCardPreviewScene(scene: .enterprise)
}

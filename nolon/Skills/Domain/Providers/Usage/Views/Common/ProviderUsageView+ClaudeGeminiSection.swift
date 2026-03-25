import SwiftUI
import AppKit
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
import NolonUI

struct ProviderUsageSectionEmptyState {
    let title: String
    let systemImage: String
    let description: String
}

enum ProviderUsageAccountsSectionState<Content> {
    case loading
    case empty(ProviderUsageSectionEmptyState)
    case content(Content)
}

extension ProviderUsageView {
    var usageContent: some View {
        let capabilities = viewModel.capabilities

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if capabilities.isCodexFamily {
                    codexManagementCard
                    if !gatewayCardsViewModel.gatewayCards.isEmpty {
                        gatewayCardsSection
                    }
                    codexAccountsSection
                } else {
                    nonCodexAccountsSection
                }

                if capabilities.showsTokenTrend {
                    tokenTrendSection
                }
            }
            .padding(.trailing, 12)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var nonCodexAccountsSection: some View {
        let cards = viewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: viewModel.preferredUnifiedCardLiveOutcome,
            isLoading: viewModel.isLoading
        )
        let outcomes = viewModel.displayedOutcomesForUnifiedAccounts()
        let state = nonCodexSectionState(cards: cards, outcomes: outcomes)

        return Group {
            if viewModel.capabilities.showsUnifiedImportCallout {
                geminiImportCallout
            }

            switch state {
            case .loading:
                nonCodexLoadingContent(provider: provider)
            case let .empty(emptyState):
                ProviderUsageEmptyStateCard(
                    title: LocalizedStringKey(emptyState.title),
                    systemImage: emptyState.systemImage,
                    descriptionText: Text(emptyState.description)
                )
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: emptyState.title)])
            case let .content((cards, outcomes)):
                if !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = viewModel.unifiedAccountSectionTitle(defaultProviderName: provider.name) {
                            Text(title)
                                .font(.headline)
                        }

                        ProviderUsageUnifiedAccountCardGrid(
                            provider: provider,
                            cards: cards.map(\.data),
                            isLoading: false,
                            columns: claudeAccountColumns,
                            layoutMode: Self.shouldUseCompactUnifiedListRows(
                                layoutMode: viewModel.accountLayoutMode,
                                accountCount: cards.count
                            ) ? .list : .cards,
                            onTap: { cardData in
                                guard let card = cards.first(where: { $0.data.id == cardData.id }) else { return }
                                Task { await card.onTap() }
                            },
                            onAction: { cardData, action in
                                guard let card = cards.first(where: { $0.data.id == cardData.id }) else { return }
                                Task { await card.onAction(action) }
                            }
                        )
                        .id(cards.map(\.id).joined(separator: "|"))
                    }
                }

                ForEach(outcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome, isLoading: viewModel.isLoading)
                }
            }
        }
    }

    private func nonCodexLoadingContent(provider: Provider) -> some View {
        ProviderUsageUnifiedAccountCardGrid(
            provider: provider,
            cards: [],
            isLoading: true,
            columns: claudeAccountColumns,
            layoutMode: .cards,
            onTap: { _ in },
            onAction: { _, _ in }
        )
    }

    private func nonCodexSectionState(
        cards: [ProviderUsageUnifiedAccountCardModel],
        outcomes: [ProviderAccountUsageOutcome]
    ) -> ProviderUsageAccountsSectionState<([ProviderUsageUnifiedAccountCardModel], [ProviderAccountUsageOutcome])> {
        if viewModel.isLoading && cards.isEmpty && outcomes.isEmpty {
            return .loading
        }
        if cards.isEmpty, let emptyState = viewModel.unifiedAccountEmptyState {
            return .empty(
                .init(
                    title: emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: emptyState.description
                )
            )
        }
        return .content((cards, outcomes))
    }

    var geminiImportCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString(
                "gemini.import.inline.title",
                value: "Detected existing Gemini login",
                comment: "Inline Gemini import title"
            ))
            .font(.headline)

            Text(NSLocalizedString(
                "gemini.import.inline.body",
                value: "Nolon found an existing Gemini CLI session on this machine. Import it to activate this provider immediately.",
                comment: "Inline Gemini import body"
            ))
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)

            HStack(spacing: 8) {
                Button(NSLocalizedString(
                    "gemini.import.inline.import",
                    value: "Import Existing Login",
                    comment: "Inline Gemini import CTA"
                )) {
                    viewModel.gemini.presentImportConfirmation()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString(
                    "gemini.import.inline.oauth",
                    value: "Sign in with OAuth",
                    comment: "Inline Gemini OAuth CTA"
                )) {
                    viewModel.gemini.continueOAuthLoginWithoutImport()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
    }
}

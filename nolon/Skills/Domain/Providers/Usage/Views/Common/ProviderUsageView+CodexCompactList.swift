import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation

extension ProviderUsageView {
    func codexOutcomesContainer(_ outcomes: [ProviderAccountUsageOutcome]) -> some View {
        Group {
            if Self.shouldUseCompactCodexListRows(layoutMode: viewModel.accountLayoutMode) {
                VStack(alignment: .leading, spacing: 0) {
                    codexListTableHeader

                    ForEach(Array(outcomes.enumerated()), id: \.element.id) { index, outcome in
                        codexOutcomeCard(outcome: outcome)
                        if index < outcomes.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.Background.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                    ForEach(outcomes) { outcome in
                        codexOutcomeCard(outcome: outcome)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func codexOutcomeCard(outcome: ProviderAccountUsageOutcome) -> some View {
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let model = accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            hasActiveGatewayCardSelection: hasActiveGatewayCardSelection,
            isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
        )
        let cardView = codexCompactSnapshotView(model: model)

        if let accountId = model.accountID, accountsViewModel.codex.isMultiSelectionEnabled {
            let selectionBinding = Binding<Set<UUID>>(
                get: { accountsViewModel.codex.selectedAccountIDs },
                set: { accountsViewModel.codex.selectedAccountIDs = $0 }
            )
            GenericSelectionControl(
                value: accountId,
                selections: selectionBinding,
                onToggle: {
                    if hasActiveGatewayCardSelection {
                        gatewayCardsViewModel.clearActiveGatewayCardSelection()
                    }
                }
            ) { _ in
                cardView
            }
            .draggable(CodexGatewayAccountDropItem(accountID: accountId))
        } else {
            let tappableCardView = cardView.onTapGesture {
                guard let accountId = model.accountID else { return }
                if hasActiveGatewayCardSelection {
                    gatewayCardsViewModel.clearActiveGatewayCardSelection()
                }
                let shouldActivate = accountsViewModel.codex.shouldActivateAccountOnTap(
                    id: accountId,
                    hasActiveGatewayCardSelection: hasActiveGatewayCardSelection
                )
                guard shouldActivate else { return }
                accountsViewModel.codex.requestActivateAccount(id: accountId)
            }

            if let accountId = model.accountID {
                tappableCardView.draggable(CodexGatewayAccountDropItem(accountID: accountId))
            } else {
                tappableCardView
            }
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        model: ProviderUsageCodexCardModel
    ) -> some View {
        Group {
            if Self.shouldUseCompactCodexListRows(layoutMode: viewModel.accountLayoutMode) {
                codexCompactListRow(
                    model: model
                )
            } else {
                UnifiedAccountCard(
                    data: model.data,
                    onTap: { _ in },
                    onAction: { _, action in
                        accountsViewModel.codex.handleUsageCardAction(action, model: model)
                    }
                )
            }
        }
        .if(Self.shouldEnableCodexTextSelection(layoutMode: viewModel.accountLayoutMode)) { view in
            view.textSelection(.enabled)
        }
    }

    private func codexCompactListRow(
        model: ProviderUsageCodexCardModel
    ) -> some View {
        let usageWindows = compactUsageWindows(from: model.data)
        return HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(compactStatusColor(presentation: model.presentation, badge: model.data.header.badge))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.data.header.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondary = compactSecondaryText(from: model.data.header), !secondary.isEmpty {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(compactPlanText(from: model.data.header))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: CodexListLayout.planColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(usageWindows) { window in
                    HStack(spacing: 6) {
                        Text(window.title)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .frame(width: 46, alignment: .leading)
                        compactUsageProgressBar(remainingPercent: window.remainingPercent)
                    }
                }
            }
            .frame(width: CodexListLayout.usageColumnWidth, alignment: .leading)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(compactRowBackgroundColor(presentation: model.presentation))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(model.data.menuActions) { action in
                Button(role: action.role) {
                    accountsViewModel.codex.handleUsageCardAction(action.actionID, model: model)
                } label: {
                    if let symbol = action.systemImage, !symbol.isEmpty {
                        Label(action.title, systemImage: symbol)
                    } else {
                        Text(action.title)
                    }
                }
                .disabled(!action.isEnabled)
            }
        }
    }

    private func compactRowBackgroundColor(presentation: AccountCardPresentation) -> Color {
        switch presentation {
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.12)
        default:
            return .clear
        }
    }

    private var codexListTableHeader: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Codex account list table account column"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Codex account list table plan column"))
                .frame(width: CodexListLayout.planColumnWidth, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Codex account list table usage column"))
                .frame(width: CodexListLayout.usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, 8)
    }

    private func compactUsageWindows(from data: AccountCardViewData) -> [CodexListUsageWindow] {
        guard case let .quota(quota) = data.body, let usage = quota.usage else {
            return [.init(id: "none", title: "-", remainingPercent: 0)]
        }
        let metadata = ProviderUsageRegistry.metadata(for: quota.provider)
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: quota.provider)
            .prefix(3)
            .map { item in
                let title: String
                switch item.id {
                case "primary":
                    title = metadata?.sessionLabel ?? "Session"
                case "secondary":
                    title = metadata?.weeklyLabel ?? "Weekly"
                default:
                    title = item.title
                }
                return .init(
                    id: item.id,
                    title: title,
                    remainingPercent: item.window.remainingPercent
                )
            }
    }

    private func compactUsageProgressBar(remainingPercent: Double) -> some View {
        let normalized = max(0, min(100, remainingPercent.isInfinite ? 100 : remainingPercent))
        let progress = normalized / 100
        let color = compactQuotaColor(for: remainingPercent)
        return HStack(spacing: 8) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.22))
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)

            Text(remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized))
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func compactQuotaColor(for remainingPercent: Double) -> Color {
        if remainingPercent.isInfinite { return DesignSystem.Colors.Status.success }
        if remainingPercent < 10 { return DesignSystem.Colors.Status.error }
        if remainingPercent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    private func compactSecondaryText(from header: AccountSummaryCardHeaderModel) -> String? {
        let eyebrow = header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let eyebrow, !eyebrow.isEmpty, let meta, !meta.isEmpty {
            return "\(eyebrow) • \(meta)"
        }
        if let eyebrow, !eyebrow.isEmpty {
            return eyebrow
        }
        if let meta, !meta.isEmpty {
            return meta
        }
        return nil
    }

    private func compactPlanText(from header: AccountSummaryCardHeaderModel) -> String {
        let raw = header.subtitle ?? "-"
        let plan = raw
            .split(separator: "•")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (plan?.isEmpty == false) ? plan! : "-"
    }

    private func compactStatusColor(
        presentation: AccountCardPresentation,
        badge: AccountSummaryCardBadgeModel?
    ) -> Color {
        if let badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        switch presentation.selectionStyle {
        case .active, .selected:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.Status.warning
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }

}

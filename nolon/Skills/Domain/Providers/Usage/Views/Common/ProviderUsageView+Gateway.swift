import SwiftUI
import AppKit
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import NolonUIFoundation
import NolonUI

// MARK: - Codex Gateway Section

private enum GatewayCandidateSectionKind {
    case relay
    case openAI
    case premium
    case generic
}

extension ProviderUsageView {
    private var codexAccountsLoadingSkeleton: some View {
        Group {
            if viewModel.accountLayoutMode == .list {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        UnifiedAccountCardSkeleton(providerName: provider.name)
                    }
                }
            } else {
                NolonUI.AdaptiveCardGrid(columns: codexAccountColumns) {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        UnifiedAccountCardSkeleton(providerName: provider.name)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gatewayCardsHeader: some View {
        HStack(spacing: 8) {
            Button {
                gatewayCardsViewModel.toggleGatewayCardsSectionCollapsed()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: gatewayCardsViewModel.isGatewayCardsSectionCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

                    Label(
                        NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title"),
                        systemImage: "square.stack.3d.up.fill"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.primary)

                    Text("\(gatewayCardsViewModel.gatewayCards.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NolonUI.DesignSystem.Colors.Component.controlFillSubtle)
                        .clipShape(Capsule())
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    var codexAccountsSection: some View {
        let state = codexAccountsSectionState

        return Group {
            switch state {
            case let .empty(emptyState):
                ProviderUsageEmptyStateCard(
                    title: LocalizedStringKey(emptyState.title),
                    systemImage: emptyState.systemImage,
                    descriptionText: Text(emptyState.description)
                )
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: emptyState.title)])
            case .loading:
                codexAccountsLoadingSkeleton
            case let .content(sections):
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        codexAccountSectionHeader(section: section)

                        if !viewModel.codex.isSectionCollapsed(section.id) {
                            codexOutcomesContainer(section.items)
                        }
                    }
                }
                .animation(.snappy(duration: 0.2), value: viewModel.codex.collapsedSectionIDs)
            }
        }
    }

    private var codexAccountsSectionState: ProviderUsageAccountsSectionState<[ProviderUsageEngine.CodexAccountDisplaySection]> {
        if accountsViewModel.codex.accounts.isEmpty && !viewModel.isLoading {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                    systemImage: "person.crop.circle.badge.plus",
                    description: NSLocalizedString(
                        "codex.accounts.empty.desc",
                        value: "Add a snapshot of Codex auth.json to quickly switch accounts.",
                        comment: "Empty state description"
                    )
                )
            )
        }
        if viewModel.isLoading && accountsViewModel.codex.accountOutcomes.isEmpty {
            return .loading
        }
        if viewModel.codex.accountDisplaySections.isEmpty && viewModel.codex.hasActiveAccountFilters {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.filtered_empty.title", value: "没有可显示的账号", comment: "All accounts hidden by zero quota filter title"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: codexFilteredEmptyDescription
                )
            )
        }
        if viewModel.codex.accountDisplaySections.isEmpty {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.empty_unexpected.title", value: "暂无可展示账号", comment: "Codex empty fallback title"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: NSLocalizedString(
                        "codex.accounts.empty_unexpected.desc",
                        value: "已加载账号数据，但当前卡片列表为空。请尝试刷新或切换分组/筛选。",
                        comment: "Codex empty fallback description"
                    )
                )
            )
        }
        return .content(viewModel.codex.accountDisplaySections)
    }

    @ViewBuilder
    private func codexAccountSectionHeader(
        section: ProviderUsageEngine.CodexAccountDisplaySection
    ) -> some View {
        if let title = section.title {
            HStack(spacing: 8) {
                Button {
                    viewModel.codex.toggleSection(section.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.codex.isSectionCollapsed(section.id) ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.primary)
                        Text(
                            "(\(section.items.count) / \(viewModel.codex.accountSectionTotalCountByID[section.id, default: section.items.count]))"
                        )
                            .font(.caption)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if accountsViewModel.codex.isMultiSelectionEnabled && !section.items.isEmpty {
                    Button(viewModel.codex.isSectionFullySelected(section)
                        ? NSLocalizedString("codex.import.sheet.deselect_all", value: "取消全选", comment: "Deselect all")
                        : NSLocalizedString("codex.import.sheet.select_all", value: "全选", comment: "Select all")
                    ) {
                        viewModel.codex.toggleSectionSelection(section)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }

    private var codexFilteredEmptyDescription: String {
        switch (viewModel.codex.hideZeroQuotaAccounts, viewModel.codex.hideErroredAccounts) {
        case (true, true):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc.hide_zero_and_error",
                value: "当前已隐藏无额度或报错账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota and errored filters"
            )
        case (true, false):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc",
                value: "当前已隐藏最长额度窗口为 0% 的账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota filter description"
            )
        case (false, true):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc.hide_error",
                value: "当前已隐藏报错账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by errored filter description"
            )
        case (false, false):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc",
                value: "当前已隐藏最长额度窗口为 0% 的账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota filter description"
            )
        }
    }

    @ViewBuilder
    var codexManagementCard: some View {
        if let status = viewModel.codex.managementStatus, status.needsEnable || status.needsMigration {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.management.title", value: "管理状态", comment: "Codex management status"))
                        .font(.headline)
                    Text(NSLocalizedString("codex.management.desc", value: "首次使用建议先启用管理并执行数据迁移。", comment: "Codex management description"))
                        .font(.caption)
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                }
                Spacer()
                Button(NSLocalizedString("codex.management.enable", value: "启用管理", comment: "Enable codex management")) {
                    Task { await viewModel.codex.enableManagement() }
                }
                Button(NSLocalizedString("codex.management.migrate", value: "数据迁移", comment: "Migrate codex data")) {
                    Task { await viewModel.codex.migrateManagementData() }
                }
            }
            .padding(12)
            .background(NolonUI.DesignSystem.Colors.Component.controlFillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: NolonUI.DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
    }

    var gatewayCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            gatewayCardsHeader

            if !gatewayCardsViewModel.isGatewayCardsSectionCollapsed {
                gatewayCardsContainer(gatewayCardsViewModel.gatewayCards)
            }
        }
        .animation(.snappy(duration: 0.2), value: gatewayCardsViewModel.isGatewayCardsSectionCollapsed)
        .debugCardLocator(gatewayCardsDebugPageMarkerItems)
    }

    @ViewBuilder
    private func gatewayCardsContainer(_ cards: [CodexGatewayCard]) -> some View {
        NolonUI.GatewayCardListModule(
            items: cards,
            layoutMode: viewModel.accountLayoutMode == .list ? .list : .cards,
            columns: codexAccountColumns,
            spacing: 12
        ) { card in
            gatewayCardView(card: card)
        }
    }

    private func gatewayCardView(card: CodexGatewayCard) -> some View {
        let members = viewModel.codex.gatewayMembers(for: card)
        let memberItems = members.map { member in
            NolonUI.GatewayCardMemberItem(
                id: member.id,
                title: member.title,
                plan: member.plan
            )
        }
        let isTargeted = targetingGatewayCardID == card.id
        let isActiveGateway = gatewayCardsViewModel.gatewayCardsState.lastUsedCardID == card.id
        let presentation: AccountCardPresentation = (isTargeted || isActiveGateway) ? .selected : .neutral
        let isCompact = viewModel.codex.usesCompactListRows
        let memberDisplayLimit = viewModel.codex.gatewayMemberDisplayLimit
        let memberRowMaxHeight = viewModel.codex.gatewayMemberRowMaxHeight

        return NolonUI.GatewayCardModule(
            presentation: presentation,
            title: card.name,
            memberCountText: String(
                format: NSLocalizedString(
                    "codex.gateway.cards.members.count",
                    value: "%d 个成员",
                    comment: "Gateway card members count"
                ),
                members.count
            ),
            members: memberItems,
            isCompact: isCompact,
            memberDisplayLimit: memberDisplayLimit,
            memberRowMaxHeight: memberRowMaxHeight
        )
        .animation(NolonUI.DesignSystem.Animations.springQuick, value: isTargeted || isActiveGateway)
        .contentShape(Rectangle())
        .onTapGesture {
            handleGatewayCardSelection(cardID: card.id)
        }
        .dropDestination(for: CodexGatewayAccountDropItem.self) { items, _ in
            handleGatewayCardDrop(accountIDs: items.map(\.accountID), cardID: card.id)
        } isTargeted: { targeted in
            targetingGatewayCardID = GenericSelectionStateResolver.resolveHoverSelection(
                current: targetingGatewayCardID,
                hovered: card.id,
                isHovering: targeted
            )
        }
        .dropDestination(for: String.self) { items, _ in
            handleLegacyGatewayCardDrop(items: items, cardID: card.id)
        }
        .contextMenu {
            Button {
                handleGatewayCardSelection(cardID: card.id, openPicker: true)
            } label: {
                Label(
                    NSLocalizedString(
                        "codex.gateway.cards.action.add_accounts",
                        value: "添加账号",
                        comment: "Add accounts to gateway card"
                    ),
                    systemImage: "plus"
                )
            }

            Divider()

            if ProviderUsageAccountsViewModel.CodexState.shouldShowActivateGatewayContextAction(
                isActiveGateway: isActiveGateway
            ) {
                Button {
                    handleGatewayCardSelection(cardID: card.id)
                } label: {
                    Label(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"), systemImage: "checkmark.circle")
                }
            }
            Button {
                if let name = promptGatewayCardName(
                    title: NSLocalizedString("codex.gateway.cards.rename.title", value: "重命名网关卡片", comment: "Rename gateway card title"),
                    defaultValue: card.name
                ) {
                    gatewayCardsViewModel.renameGatewayCard(cardID: card.id, name: name)
                }
            } label: {
                Label(NSLocalizedString("rename", value: "Rename", comment: "Rename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                gatewayCardsViewModel.deleteGatewayCard(cardID: card.id)
            } label: {
                Label(NSLocalizedString("delete", value: "Delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .debugCardLocator(gatewayCardsDebugPageMarkerItems + [PageMarkerItem(title: card.name)])
    }

    var gatewayCardPickerSheet: some View {
        NolonUI.GatewayCardPickerSheetView(
            data: GatewayCardPickerSheetData(
                title: NSLocalizedString("codex.gateway.cards.picker.title", value: "选择目标网关卡片", comment: "Gateway card picker title"),
                subtitle: String(
                    format: NSLocalizedString(
                        "codex.gateway.cards.picker.selected_count",
                        value: "将加入 %d 个已选账号",
                        comment: "Gateway picker selected count"
                    ),
                    gatewayCardsViewModel.pendingGatewaySelectionAccountIDs.count
                ),
                items: gatewayCardsViewModel.gatewayCards.map { card in
                    GatewayCardPickerItemData(
                        id: card.id,
                        title: card.name,
                        countText: "\(card.memberAccountIDs.count)"
                    )
                },
                cancelTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")
            ),
            onSelect: { cardID in
                gatewayCardsViewModel.confirmAddPendingAccounts(to: cardID)
            },
            onCancel: {
                gatewayCardsViewModel.dismissGatewayCardPicker()
            }
        )
    }

    func gatewayAccountSelectionSheet(cardID: UUID) -> some View {
        let card = gatewayCardsViewModel.gatewayCards.first(where: { $0.id == cardID })
        let cardName = card?.name ?? NSLocalizedString("codex.gateway.cards.unknown", value: "网关卡片", comment: "Gateway card fallback name")
        let title = String(
            format: NSLocalizedString(
                "codex.gateway.accounts.picker.title",
                value: "为 %@ 选择账号",
                comment: "Gateway account picker title"
            ),
            cardName
        )

        return GatewayAccountSelectionSheetView(
            title: title,
            listSections: gatewayAccountCandidateListSections(for: cardID),
            selections: $gatewayAccountPickerSelection,
            cancelTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel"),
            confirmTitle: NSLocalizedString(
                "codex.gateway.accounts.picker.add",
                value: "加入网关",
                comment: "Add accounts to gateway card"
            ),
            onCancel: dismissGatewayAccountPicker,
            onConfirm: confirmGatewayAccountPickerSelection,
            debugPageMarkerItems: gatewayCardsDebugPageMarkerItems + [PageMarkerItem(title: title)]
        )
    }

    private func gatewayAccountCandidateListSections(for cardID: UUID) -> [NolonUI.AccountListModeSection] {
        let usageListItemsByAccountID = gatewayCandidateUsageListItemsByAccountID()
        return gatewayCardsViewModel.gatewayCandidateSections(for: cardID).map { section in
            NolonUI.AccountListModeSection(
                id: section.id,
                title: section.title,
                items: section.items.map { account in
                    if let existing = usageListItemsByAccountID[account.id] {
                        return existing
                    }

                    let displayName = gatewayCandidateTitle(for: account)
                    let subtitle = gatewayCandidateSubtitle(for: account, title: displayName)
                    return NolonUI.AccountListModeItem(
                        id: account.id.uuidString,
                        presentation: .neutral,
                        header: .init(
                            eyebrow: nil,
                            title: displayName,
                            subtitle: nil,
                            meta: subtitle,
                            badge: nil
                        ),
                        usageWindows: [.init(id: "none", title: "-", progress: 0, percentText: "0%")]
                    )
                }
            )
        }
    }

    private func gatewayCandidateUsageListItemsByAccountID() -> [UUID: NolonUI.AccountListModeItem] {
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let models = viewModel.codex.accountDisplaySections
            .flatMap(\.items)
            .map {
                accountsViewModel.codex.makeUsageCardModel(
                    outcome: $0,
                    hasActiveGatewayCardSelection: hasActiveGatewayCardSelection,
                    isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
                )
            }

        var result: [UUID: NolonUI.AccountListModeItem] = [:]
        for model in models {
            guard let accountID = model.accountID else { continue }
            result[accountID] = .init(
                id: accountID.uuidString,
                presentation: model.presentation,
                header: model.data.header,
                usageWindows: accountListModeUsageWindows(from: model.data),
                menuActions: []
            )
        }
        return result
    }

    private func accountListModeUsageWindows(from data: AccountCardViewData) -> [NolonUI.AccountListModeUsageWindow] {
        compactUsageWindows(from: data).map {
            let normalized = max(0, min(100, $0.remainingPercent.isInfinite ? 100 : $0.remainingPercent))
            return .init(
                id: $0.id,
                title: $0.title,
                progress: CGFloat(normalized / 100),
                percentText: $0.remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized)
            )
        }
    }

    private func gatewayCandidateTitle(for account: CodexAuthAccount) -> String {
        let summary = accountsViewModel.codex.accountSummaries[account.id]
        return AccountDisplayTextSupport.codexSnapshotLabel(summary: summary, account: account)
    }

    private func gatewayCandidateSectionKind(for title: String) -> GatewayCandidateSectionKind {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return .relay
        }
        if normalized.contains("openai") {
            return .openAI
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return .premium
        }
        return .generic
    }

    private func gatewayCandidateSectionIcon(for title: String) -> String {
        switch gatewayCandidateSectionKind(for: title) {
        case .relay:
            return "network"
        case .openAI:
            return "bolt.shield"
        case .premium:
            return "sparkles"
        case .generic:
            return "square.grid.2x2"
        }
    }

    private func gatewayCandidateSectionTone(for title: String) -> GatewayCandidateSectionTone {
        switch gatewayCandidateSectionKind(for: title) {
        case .relay:
            return .relay
        case .openAI:
            return .openAI
        case .premium:
            return .premium
        case .generic:
            return .generic
        }
    }

    private func gatewayCandidateSubtitle(for account: CodexAuthAccount, title: String) -> String? {
        AccountDisplayTextSupport.codexSubtitle(
            title: title,
            email: accountsViewModel.codex.accountSummaries[account.id]?.email,
            plan: nil
        )
    }

    private func presentGatewayAccountPicker(for cardID: UUID) {
        gatewayAccountPickerCardID = cardID
        gatewayAccountPickerSelection = []
    }

    private func handleGatewayCardSelection(cardID: UUID, openPicker: Bool = false) {
        let shouldPromptAddAccounts = gatewayCardsViewModel.activateGatewayCard(cardID: cardID)
        if openPicker || shouldPromptAddAccounts {
            presentGatewayAccountPicker(for: cardID)
            return
        }
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    func dismissGatewayAccountPicker() {
        gatewayAccountPickerCardID = nil
        gatewayAccountPickerSelection = []
    }

    private func confirmGatewayAccountPickerSelection() {
        guard let cardID = gatewayAccountPickerCardID else { return }
        let orderedIDs = gatewayCardsViewModel
            .gatewayCandidateAccounts(for: cardID)
            .map(\.id)
            .filter { gatewayAccountPickerSelection.contains(IDBox($0)) }
        guard !orderedIDs.isEmpty else {
            dismissGatewayAccountPicker()
            return
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: orderedIDs, cardID: cardID)
        dismissGatewayAccountPicker()
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    private func handleLegacyGatewayCardDrop(items: [String], cardID: UUID) -> Bool {
        handleGatewayCardDrop(
            accountIDs: CodexGatewayDropParser.accountIDs(fromLegacyStrings: items),
            cardID: cardID
        )
    }

    private func handleGatewayCardDrop(accountIDs droppedIDs: [UUID], cardID: UUID) -> Bool {
        guard !droppedIDs.isEmpty else { return false }
        if accountsViewModel.codex.isMultiSelectionEnabled,
           droppedIDs.contains(where: { accountsViewModel.codex.isAccountSelected(id: $0) }) {
            gatewayCardsViewModel.addAccountsToGatewayCard(
                accountIDs: accountsViewModel.codex.selectedAccountIDsInDisplayOrder,
                cardID: cardID
            )
            return true
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: droppedIDs, cardID: cardID)
        return true
    }

    func createGatewayCardWithPrompt() {
        let defaultName = String(
            format: NSLocalizedString(
                "codex.gateway.cards.default_name",
                value: "网关 %d",
                comment: "Gateway default card name"
            ),
            gatewayCardsViewModel.gatewayCards.count + 1
        )
        if let name = promptGatewayCardName(
            title: NSLocalizedString("codex.gateway.cards.create.title", value: "新建网关卡片", comment: "Create gateway card title"),
            defaultValue: defaultName
        ) {
            _ = gatewayCardsViewModel.createGatewayCard(name: name)
        }
    }

    private func promptGatewayCardName(title: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: NSLocalizedString("generic.ok", value: "OK", comment: "OK"))
        alert.addButton(withTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel"))

        let textField = NSTextField(string: defaultValue)
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var tokenTrendSection: some View {
        ProviderTokenTrendSection(
            snapshot: tokenTrendViewModel.tokenTrendSnapshot,
            isLoading: tokenTrendViewModel.shouldShowLoadingSkeleton,
            errorMessage: tokenTrendViewModel.tokenTrendErrorMessage,
            range: tokenTrendViewModel.tokenTrendRange,
            onRangeChange: { tokenTrendViewModel.setRange($0) },
            onRefresh: { tokenTrendViewModel.refreshNow() },
            debugPageMarkerItems: tokenTrendDebugPageMarkerItems
        )
    }
}

struct ClaudeAccountEditorSheet: View {
    @Binding var draft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft?
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    private var currentDraft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft? {
        draft
    }

    private static let fallbackAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private var fallbackDraft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft {
        .init(
            mode: .create,
            accountID: Self.fallbackAccountID,
            name: "",
            credentialType: .authToken,
            credentialValue: "",
            baseURL: "",
            anthropicModel: "gpt-5",
            anthropicReasoningModel: "",
            anthropicDefaultHaikuModel: "gpt-5(minimal)",
            anthropicDefaultSonnetModel: "gpt-5(medium)",
            anthropicDefaultOpusModel: "gpt-5(high)"
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(NSLocalizedString("claude.accounts.editor.title", value: "编辑 Claude 账号", comment: "Claude account editor title"))
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Group {
                    if currentDraft != nil {
                        Form {
                            Section(
                                NSLocalizedString(
                                    "claude.accounts.editor.section.basic",
                                    value: "基础信息",
                                    comment: "Claude account editor basic section title"
                                )
                            ) {
                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.name",
                                        value: "账号名称",
                                        comment: "Claude account editor name field"
                                    ),
                                    text: binding(\.name)
                                )

                                Picker(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.credential_type",
                                        value: "鉴权类型",
                                        comment: "Claude account editor credential type field"
                                    ),
                                    selection: binding(\.credentialType)
                                ) {
                                    Text(NSLocalizedString("claude.accounts.editor.credential.auth_token", value: "Auth Token", comment: "Claude auth token type")).tag(ClaudeCredentialType.authToken)
                                    Text(NSLocalizedString("claude.accounts.editor.credential.api_key", value: "API Key", comment: "Claude API key type")).tag(ClaudeCredentialType.apiKey)
                                }

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.credential_value",
                                        value: "密钥",
                                        comment: "Claude account editor credential field"
                                    ),
                                    text: binding(\.credentialValue)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.base_url",
                                        value: "Base URL",
                                        comment: "Claude account editor base url field"
                                    ),
                                    text: binding(\.baseURL)
                                )
                            }

                            Section(
                                NSLocalizedString(
                                    "claude.accounts.editor.section.models",
                                    value: "模型配置",
                                    comment: "Claude account editor models section title"
                                )
                            ) {
                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.model",
                                        value: "默认模型 (ANTHROPIC_MODEL)",
                                        comment: "Claude account editor default model field"
                                    ),
                                    text: binding(\.anthropicModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.reasoning_model",
                                        value: "推理模型 (ANTHROPIC_REASONING_MODEL)",
                                        comment: "Claude account editor reasoning model field"
                                    ),
                                    text: binding(\.anthropicReasoningModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.haiku_model",
                                        value: "Haiku 模型 (ANTHROPIC_DEFAULT_HAIKU_MODEL)",
                                        comment: "Claude account editor haiku model field"
                                    ),
                                    text: binding(\.anthropicDefaultHaikuModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.sonnet_model",
                                        value: "Sonnet 模型 (ANTHROPIC_DEFAULT_SONNET_MODEL)",
                                        comment: "Claude account editor sonnet model field"
                                    ),
                                    text: binding(\.anthropicDefaultSonnetModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.opus_model",
                                        value: "Opus 模型 (ANTHROPIC_DEFAULT_OPUS_MODEL)",
                                        comment: "Claude account editor opus model field"
                                    ),
                                    text: binding(\.anthropicDefaultOpusModel)
                                )
                            }

                            if let errorMessage, !errorMessage.isEmpty {
                                Section {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .formStyle(.grouped)
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("claude.accounts.editor.unavailable.title", value: "无法编辑账号", comment: "Claude account editor unavailable title"),
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(NSLocalizedString("claude.accounts.editor.unavailable.desc", value: "账号已不存在，请刷新后重试。", comment: "Claude account editor unavailable description"))
                        )
                        .padding(24)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button(NSLocalizedString("generic.save", value: "Save", comment: "Save")) {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentDraft == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }

            NolonUI.FloatingCloseButton(
                help: NSLocalizedString("generic.close", value: "Close", comment: "Close"),
                enableCancelShortcut: true,
                action: onCancel
            )
            .padding(16)
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft, T>) -> Binding<T> {
        Binding(
            get: {
                let resolvedDraft = draft ?? fallbackDraft
                return resolvedDraft[keyPath: keyPath]
            },
            set: { newValue in
                guard var draft else { return }
                draft[keyPath: keyPath] = newValue
                self.draft = draft
            }
        )
    }
}

extension ProviderFetchKind {
    var nolonLabel: String {
        switch self {
        case .web:
            return NSLocalizedString("usage.source.web", value: "Web", comment: "Web")
        case .cli:
            return NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI")
        case .oauth:
            return NSLocalizedString("usage.source.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken:
            return NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token")
        case .localProbe:
            return NSLocalizedString("usage.source.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard:
            return NSLocalizedString("usage.source.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

extension ProviderFetchStrategyKind {
    var nolonLabel: String {
        switch self {
        case .direct:
            NSLocalizedString("usage.strategy.direct", value: "Direct", comment: "Direct fetch")
        case .fallback:
            NSLocalizedString("usage.strategy.fallback", value: "Fallback", comment: "Fallback fetch")
        }
    }
}

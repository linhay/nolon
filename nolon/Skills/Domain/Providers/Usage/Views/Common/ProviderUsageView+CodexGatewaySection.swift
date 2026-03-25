import SwiftUI
import AppKit
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
import NolonUI

extension ProviderUsageView {
    var codexAccountsSection: some View {
        let state = codexAccountsSectionState

        return Group {
            switch state {
            case let .empty(emptyState):
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: Text(emptyState.description)
                        .dsSecondaryText(font: .body)
                )
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: emptyState.title)])
            case .loading:
                Group {
                    if viewModel.codex.accountLayoutMode == .list {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                                UnifiedAccountCardSkeleton(providerName: provider.name)
                            }
                        }
                    } else {
                        LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                            ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                                UnifiedAccountCardSkeleton(providerName: provider.name)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        Text(
                            "(\(section.items.count) / \(viewModel.codex.accountSectionTotalCountByID[section.id, default: section.items.count]))"
                        )
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
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
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
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
            .background(DesignSystem.Colors.Component.controlFillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
    }

    var gatewayCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                    Button {
                        gatewayCardsViewModel.toggleGatewayCardsSectionCollapsed()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: gatewayCardsViewModel.isGatewayCardsSectionCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)

                        Label(
                            NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title"),
                            systemImage: "square.stack.3d.up.fill"
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text("\(gatewayCardsViewModel.gatewayCards.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.Component.controlFillSubtle)
                            .clipShape(Capsule())
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }

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
            layoutMode: viewModel.codex.accountLayoutMode == .list ? .list : .cards,
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
        let isCompact = Self.shouldUseCompactCodexListRows(layoutMode: viewModel.codex.accountLayoutMode)
        let memberDisplayLimit = Self.gatewayMemberDisplayLimit(layoutMode: viewModel.codex.accountLayoutMode)
        let memberRowMaxHeight = Self.gatewayMemberRowMaxHeight(layoutMode: viewModel.codex.accountLayoutMode)
        
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
        .animation(DesignSystem.Animations.springQuick, value: isTargeted || isActiveGateway)
        .contentShape(Rectangle())
        .onTapGesture {
            handleGatewayCardSelection(cardID: card.id)
        }
        .dropDestination(for: CodexGatewayAccountDropItem.self) { items, _ in
            handleGatewayCardDrop(items: items, cardID: card.id)
        } isTargeted: { targeted in
            targetingGatewayCardID = targeted ? card.id : (targetingGatewayCardID == card.id ? nil : targetingGatewayCardID)
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

            if Self.shouldShowActivateGatewayContextAction(isActiveGateway: isActiveGateway) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("codex.gateway.cards.picker.title", value: "选择目标网关卡片", comment: "Gateway card picker title"))
                .font(.headline)
            Text(
                String(
                    format: NSLocalizedString(
                        "codex.gateway.cards.picker.selected_count",
                        value: "将加入 %d 个已选账号",
                        comment: "Gateway picker selected count"
                    ),
                    gatewayCardsViewModel.pendingGatewaySelectionAccountIDs.count
                )
            )
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)

            List(gatewayCardsViewModel.gatewayCards) { card in
                Button {
                    gatewayCardsViewModel.confirmAddPendingAccounts(to: card.id)
                } label: {
                    HStack {
                        Text(card.name)
                        Spacer(minLength: 0)
                        Text("\(card.memberAccountIDs.count)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 200)

            HStack {
                Spacer(minLength: 0)
                Button(NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")) {
                    gatewayCardsViewModel.dismissGatewayCardPicker()
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 320)
    }

    func gatewayAccountSelectionSheet(cardID: UUID) -> some View {
        let card = gatewayCardsViewModel.gatewayCards.first(where: { $0.id == cardID })
        let candidates = gatewayCardsViewModel.gatewayCandidateAccounts(for: cardID)
        let candidateSections = gatewayCardsViewModel.gatewayCandidateSections(for: cardID)
        let cardName = card?.name ?? NSLocalizedString("codex.gateway.cards.unknown", value: "网关卡片", comment: "Gateway card fallback name")

        return VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: NSLocalizedString(
                        "codex.gateway.accounts.picker.title",
                        value: "为 %@ 选择账号",
                        comment: "Gateway account picker title"
                    ),
                    cardName
                )
            )
            .font(.headline)

            if candidates.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString(
                        "codex.gateway.accounts.picker.empty.title",
                        value: "没有可添加的账号",
                        comment: "Gateway account picker empty title"
                    ),
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text(
                        NSLocalizedString(
                            "codex.gateway.accounts.picker.empty.desc",
                            value: "当前所有账号都已在此网关卡片中。",
                            comment: "Gateway account picker empty description"
                        )
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(candidateSections) { section in
                        Section {
                            ForEach(section.items, id: \.id) { account in
                                let title = gatewayCandidateTitle(for: account)
                                let subtitle = gatewayCandidateSubtitle(for: account, title: title)
                                Button {
                                    toggleGatewayAccountPickerSelection(account.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(title)
                                                .font(.body)
                                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                                            if let subtitle, !subtitle.isEmpty {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: gatewayAccountPickerSelection.contains(account.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(
                                                gatewayAccountPickerSelection.contains(account.id)
                                                ? DesignSystem.Colors.primary
                                                : DesignSystem.Colors.Text.tertiary
                                            )
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Label(section.title, systemImage: gatewayCandidateSectionIcon(for: section.title))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(gatewayCandidateSectionForegroundColor(for: section.title))
                                    .background(
                                        gatewayCandidateSectionBackgroundColor(for: section.title),
                                        in: Capsule(style: .continuous)
                                    )
                                Text("\(section.items.count)")
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
            }

            HStack {
                Button(NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")) {
                    dismissGatewayAccountPicker()
                }
                Spacer(minLength: 0)
                Button(
                    NSLocalizedString(
                        "codex.gateway.accounts.picker.add",
                        value: "加入网关",
                        comment: "Add accounts to gateway card"
                    )
                ) {
                    confirmGatewayAccountPickerSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(gatewayAccountPickerSelection.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 360)
        .debugCardLocator(
            gatewayCardsDebugPageMarkerItems + [
                PageMarkerItem(
                    title: String(
                        format: NSLocalizedString(
                            "codex.gateway.accounts.picker.title",
                            value: "为 %@ 选择账号",
                            comment: "Gateway account picker title"
                        ),
                        cardName
                    )
                )
            ]
        )
    }

    private func gatewayCandidateTitle(for account: CodexAuthAccount) -> String {
        CodexAccountDisplayNameResolver.resolve(
            summary: accountsViewModel.codex.accountSummaries[account.id],
            relativeAuthPath: account.relativeAuthPath,
            defaultName: account.name,
            accountID: account.id
        )
    }

    private func gatewayCandidateSectionIcon(for title: String) -> String {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return "network"
        }
        if normalized.contains("openai") {
            return "bolt.shield"
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return "sparkles"
        }
        return "square.grid.2x2"
    }

    private func gatewayCandidateSectionForegroundColor(for title: String) -> Color {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return DesignSystem.Colors.Status.info
        }
        if normalized.contains("openai") {
            return DesignSystem.Colors.primary
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return DesignSystem.Colors.Status.success
        }
        return DesignSystem.Colors.Text.secondary
    }

    private func gatewayCandidateSectionBackgroundColor(for title: String) -> Color {
        gatewayCandidateSectionForegroundColor(for: title).opacity(0.14)
    }

    private func gatewayCandidateSubtitle(for account: CodexAuthAccount, title: String) -> String? {
        guard let raw = accountsViewModel.codex.accountSummaries[account.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw == title ? nil : raw
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

    private func toggleGatewayAccountPickerSelection(_ accountID: UUID) {
        if gatewayAccountPickerSelection.contains(accountID) {
            gatewayAccountPickerSelection.remove(accountID)
        } else {
            gatewayAccountPickerSelection.insert(accountID)
        }
    }

    private func confirmGatewayAccountPickerSelection() {
        guard let cardID = gatewayAccountPickerCardID else { return }
        let orderedIDs = gatewayCardsViewModel
            .gatewayCandidateAccounts(for: cardID)
            .map(\.id)
            .filter { gatewayAccountPickerSelection.contains($0) }
        guard !orderedIDs.isEmpty else {
            dismissGatewayAccountPicker()
            return
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: orderedIDs, cardID: cardID)
        dismissGatewayAccountPicker()
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    private func handleGatewayCardDrop(items: [CodexGatewayAccountDropItem], cardID: UUID) -> Bool {
        handleGatewayCardDrop(accountIDs: items.map(\.accountID), cardID: cardID)
    }

    private func handleLegacyGatewayCardDrop(items: [String], cardID: UUID) -> Bool {
        handleGatewayCardDrop(
            accountIDs: CodexGatewayDropParser.accountIDs(fromLegacyStrings: items),
            cardID: cardID
        )
    }

    private func handleGatewayCardDrop(accountIDs droppedIDs: [UUID], cardID: UUID) -> Bool {
        guard let firstID = droppedIDs.first else { return false }
        if accountsViewModel.codex.isMultiSelectionEnabled, accountsViewModel.codex.selectedAccountIDs.contains(firstID) {
            gatewayCardsViewModel.addAccountsToGatewayCard(
                accountIDs: Array(accountsViewModel.codex.selectedAccountIDs),
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

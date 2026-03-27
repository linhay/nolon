import SwiftUI
import NolonUIFoundation

public struct QuickSwitchHeaderView: View {
    let data: QuickSwitchHeaderData
    let onSelectProvider: (String) -> Void
    let onRefresh: () -> Void

    public init(
        data: QuickSwitchHeaderData,
        onSelectProvider: @escaping (String) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.data = data
        self.onSelectProvider = onSelectProvider
        self.onRefresh = onRefresh
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                providerPicker
            }

            Spacer()

            if data.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var providerPicker: some View {
        if data.providers.count > 1 {
            Menu {
                ForEach(data.providers) { provider in
                    Button {
                        onSelectProvider(provider.id)
                    } label: {
                        HStack {
                            Text(provider.name)
                            if provider.isSelected {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                pickerBadge
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            pickerBadge
        }
    }

    private var pickerBadge: some View {
        HStack(spacing: 4) {
            Text(data.providerDisplayName)
            if data.providers.count > 1 {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(DesignSystem.Colors.primary.opacity(0.15))
        .foregroundStyle(DesignSystem.Colors.primary)
        .clipShape(Capsule())
    }
}

public struct QuickSwitchSectionHeaderView: View {
    public enum Preset {
        case active
        case available
    }

    let title: String

    public init(title: String) {
        self.title = title
    }

    public init(preset: Preset) {
        switch preset {
        case .active:
            self.title = NSLocalizedString(
                "quickswitch.section.active",
                value: "当前活跃",
                comment: "Quick switch active section title"
            )
        case .available:
            self.title = NSLocalizedString(
                "quickswitch.section.available",
                value: "可用账号",
                comment: "Quick switch available section title"
            )
        }
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .padding(.leading, 4)
    }
}

public struct QuickSwitchEmptyStateView: View {
    let title: String
    let systemImage: String

    public init(
        title: String = NSLocalizedString(
            "quickswitch.empty.title",
            value: "暂无可用账号",
            comment: "Quick switch empty state title"
        ),
        systemImage: String = "person.crop.circle.badge.questionmark"
    ) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

public struct QuickSwitchAccountCardView: View {
    let data: QuickSwitchAccountCardData
    let onTap: () -> Void

    @State private var isHovered = false

    public init(
        data: QuickSwitchAccountCardData,
        onTap: @escaping () -> Void
    ) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(titleColor)
                            .lineLimit(1)

                        if let detail = data.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if data.isActive {
                        Text(data.activeBadgeTitle)
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if !data.usageWindows.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(data.usageWindows) { window in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(window.title.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    Spacer()
                                    Text("\(Int(window.remainingPercent))%")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(
                                            Int(window.remainingPercent) <= 10
                                            ? DesignSystem.Colors.Status.error
                                            : DesignSystem.Colors.Text.secondary
                                        )
                                }
                                usageProgressBar(
                                    remainingPercent: window.remainingPercent,
                                    title: window.title
                                )
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        data.isActive
                        ? DesignSystem.Colors.primary.opacity(0.06)
                        : DesignSystem.Colors.Background.elevated.opacity(0.4)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        data.isActive
                        ? DesignSystem.Colors.primary.opacity(0.4)
                        : DesignSystem.Colors.Component.border.opacity(0.3),
                        lineWidth: data.isActive ? 2 : 1
                    )
            )
            .shadow(
                color: data.isActive ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovered
            }
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }

    private var titleColor: Color {
        if data.isActive { return DesignSystem.Colors.Text.primary }
        if data.isExhausted { return DesignSystem.Colors.Text.tertiary }
        return DesignSystem.Colors.Text.secondary
    }

    private func usageProgressBar(remainingPercent: Double, title: String) -> some View {
        let normalized = max(0, min(100, remainingPercent))
        let color: Color = {
            if normalized <= 0.1 { return DesignSystem.Colors.Status.error }
            let lowercased = title.lowercased()
            if lowercased.contains("request") || lowercased.contains("primary") {
                return DesignSystem.Colors.primary
            }
            if lowercased.contains("token") || lowercased.contains("secondary") {
                return DesignSystem.Colors.secondary
            }
            return DesignSystem.Colors.Status.success
        }()

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(DesignSystem.Colors.Component.border.opacity(0.2))
                .frame(height: 6)

            Capsule()
                .fill(color)
                .frame(width: max(6, 328 * (normalized / 100.0)), height: 6)
        }
    }
}

public struct QuickSwitchExhaustedGroupView<Content: View>: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    let content: () -> Content

    public init(
        title: String = NSLocalizedString(
            "quickswitch.exhausted.title",
            value: "已耗尽账号",
            comment: "Quick switch exhausted section title"
        ),
        count: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self._isExpanded = isExpanded
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(DesignSystem.Animations.springQuick) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .black))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(title)
                        .font(.system(size: 10, weight: .bold))

                    Spacer()

                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Component.controlFillSubtle)
                        .clipShape(Capsule())
                }
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}

public struct QuickSwitchFooterToolbarView: View {
    let data: QuickSwitchFooterData
    let onTapAction: (String) -> Void
    let onTapQuit: () -> Void

    public init(
        data: QuickSwitchFooterData,
        onTapAction: @escaping (String) -> Void,
        onTapQuit: @escaping () -> Void
    ) {
        self.data = data
        self.onTapAction = onTapAction
        self.onTapQuit = onTapQuit
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(data.actions) { action in
                    actionIconButton(action)
                }
            }

            Spacer()

            Button(action: onTapQuit) {
                Text(data.quitTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionIconButton(_ action: QuickSwitchFooterActionData) -> some View {
        Button {
            onTapAction(action.id)
        } label: {
            Image(systemName: action.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.Component.controlFillSubtle)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(action.tooltip)
    }
}

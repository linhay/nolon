import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - AccountSectionHeaderView.swift"

public struct AccountSectionHeaderView: View {
    let data: AccountSectionHeaderData

    public struct Config {
        public var data: AccountSectionHeaderData

        public init(data: AccountSectionHeaderData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: AccountSectionHeaderData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        switch data.style {
        case .section(let section):
            sectionHeader(section)
        case .provider(let provider):
            providerHeader(provider)
        }
    }

    private func sectionHeader(_ section: AccountSectionHeaderData.Section) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent(for: section.tone))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(section.shortLabel)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                )

            Text(section.title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()

            Text(section.accountCountText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.border.opacity(0.35))
                .frame(height: 1)
        }
    }

    private func providerHeader(_ provider: AccountSectionHeaderData.Provider) -> some View {
        HStack(spacing: 10) {
            if let logoName = provider.logoName {
                ProviderLogoView(
                    name: provider.name,
                    logoName: logoName,
                    iconSize: 16
                )
            } else {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.9))
                    .frame(width: 8, height: 8)
            }

            Text(provider.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()
        }
    }

    private func accent(for tone: AccountSectionHeaderData.SectionTone) -> Color {
        switch tone {
        case .primary:
            return DesignSystem.Colors.primary
        case .secondary:
            return DesignSystem.Colors.secondary
        case .success:
            return DesignSystem.Colors.Status.success
        }
    }
}

// MARK: - AdaptiveCardGrid.swift"

public struct AdaptiveCardGrid<Content: View>: View {
    let columns: [GridItem]
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content

    public struct Config {
        public var columns: [GridItem]
        public var alignment: HorizontalAlignment
        public var spacing: CGFloat

        public init(
            columns: [GridItem],
            alignment: HorizontalAlignment = .leading,
            spacing: CGFloat = 12
        ) {
            self.columns = columns
            self.alignment = alignment
            self.spacing = spacing
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = config.columns
        self.alignment = config.alignment
        self.spacing = config.spacing
        self.content = content
    }

    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(columns: columns, alignment: alignment, spacing: spacing),
            content: content
        )
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

// MARK: - FormSectionBlockView.swift"

public struct FormSectionBlockView<Content: View>: View {
    let title: String
    let spacing: CGFloat
    let content: () -> Content

    public struct Config {
        public var title: String
        public var spacing: CGFloat

        public init(
            title: String,
            spacing: CGFloat = 12
        ) {
            self.title = title
            self.spacing = spacing
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = config.title
        self.spacing = config.spacing
        self.content = content
    }

    public init(
        title: String,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(title: title, spacing: spacing),
            content: content
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            content()
        }
    }
}

public struct FormSecondaryHintText: View {
    let text: String

    public struct Config {
        public var text: String

        public init(text: String) {
            self.text = text
        }
    }

    public init(config: Config) {
        self.text = config.text
    }

    public init(_ text: String) {
        self.init(config: Config(text: text))
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
    }
}

// MARK: - GenericSelectionControl.swift"

public struct GenericSelectionControl<Value: Hashable, Content: View>: View {
    @State private var viewModel = GenericSelectionControlViewModel()

    public struct Config {
        public var isSelected: Bool
        public var onToggle: () -> Void
        public var disabled: Bool

        public init(
            isSelected: Bool,
            onToggle: @escaping () -> Void,
            disabled: Bool = false
        ) {
            self.isSelected = isSelected
            self.onToggle = onToggle
            self.disabled = disabled
        }
    }

    private let isSelected: Bool
    private let onToggle: () -> Void
    private let content: (Bool) -> Content
    private let disabled: Bool

    public init(
        config: Config,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = config.isSelected
        self.onToggle = config.onToggle
        self.content = content
        self.disabled = config.disabled
    }

    public init(
        value: Value,
        selection: Binding<Value>,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.init(
            config: Config(
                isSelected: selection.wrappedValue == value,
                onToggle: {
                    selection.wrappedValue = value
                    onToggle?()
                },
                disabled: disabled
            ),
            content: content
        )
    }

    public init(
        value: Value,
        selection: Binding<Value?>,
        allowsEmptySelection: Bool = false,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.init(
            config: Config(
                isSelected: selection.wrappedValue == value,
                onToggle: {
                    if allowsEmptySelection, selection.wrappedValue == value {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = value
                    }
                    onToggle?()
                },
                disabled: disabled
            ),
            content: content
        )
    }

    public init(
        value: Value,
        selections: Binding<Set<Value>>,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.init(
            config: Config(
                isSelected: selections.wrappedValue.contains(value),
                onToggle: {
                    if selections.wrappedValue.contains(value) {
                        selections.wrappedValue.remove(value)
                    } else {
                        selections.wrappedValue.insert(value)
                    }
                    onToggle?()
                },
                disabled: disabled
            ),
            content: content
        )
    }

    public var body: some View {
        Button(action: onToggle) {
            content(isSelected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - GroupedSheetForm.swift"

public struct GroupedSheetForm<Content: View>: View {
    public struct Config {
        public var appliesSheetPadding: Bool

        public init(appliesSheetPadding: Bool = true) {
            self.appliesSheetPadding = appliesSheetPadding
        }
    }

    let appliesSheetPadding: Bool
    let content: () -> Content

    public init(config: Config, @ViewBuilder content: @escaping () -> Content) {
        self.appliesSheetPadding = config.appliesSheetPadding
        self.content = content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(config: Config(), content: content)
    }

    public init(
        appliesSheetPadding: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(config: Config(appliesSheetPadding: appliesSheetPadding), content: content)
    }

    public var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .modifier(ConditionalSheetPaddingModifier(enabled: appliesSheetPadding))
    }
}

private struct ConditionalSheetPaddingModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.sheetScrollContentPadding()
        } else {
            content
        }
    }
}

// MARK: - LiquidBackgroundView.swift"

/// Dynamic liquid background with subtle motion and texture.
public struct LiquidBackgroundView: View {
    @State private var viewModel = LiquidBackgroundViewModel()

    public struct Config {
        public var particleCount: Int

        public init(particleCount: Int = 1000) {
            self.particleCount = max(1, particleCount)
        }
    }

    private let particleCount: Int

    public init(config: Config = Config()) {
        self.particleCount = config.particleCount
    }

    public init() {
        self.init(config: Config())
    }

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Background.canvas

            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.10))
                    .frame(width: 600, height: 600)
                    .offset(
                        x: viewModel.appear ? -150 : 150,
                        y: viewModel.appear ? -100 : 100
                    )
                    .blur(radius: 100)

                Circle()
                    .fill(DesignSystem.Colors.secondary.opacity(0.08))
                    .frame(width: 800, height: 800)
                    .offset(
                        x: viewModel.appear ? 200 : -200,
                        y: viewModel.appear ? 150 : -150
                    )
                    .blur(radius: 120)
            }
            .opacity(0.35)

            Canvas { context, size in
                for _ in 0..<particleCount {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(DesignSystem.Colors.Text.quaternary)
                    )
                }
            }
            .blendMode(.overlay)
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.startAnimation()
        }
    }
}

// MARK: - MaterialPanelScaffold.swift"

public struct MaterialPanelScaffold<Header: View, Content: View, Footer: View>: View {
    public struct Config {
        public var width: CGFloat
        public var cornerRadius: CGFloat
        public var dividerOpacity: CGFloat

        public init(
            width: CGFloat = 360,
            cornerRadius: CGFloat = 20,
            dividerOpacity: CGFloat = 0.5
        ) {
            self.width = width
            self.cornerRadius = cornerRadius
            self.dividerOpacity = dividerOpacity
        }
    }

    let width: CGFloat
    let cornerRadius: CGFloat
    let dividerOpacity: CGFloat
    let header: () -> Header
    let content: () -> Content
    let footer: () -> Footer

    public init(
        config: Config,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.width = config.width
        self.cornerRadius = config.cornerRadius
        self.dividerOpacity = config.dividerOpacity
        self.header = header
        self.content = content
        self.footer = footer
    }

    public init(
        width: CGFloat = 360,
        cornerRadius: CGFloat = 20,
        dividerOpacity: CGFloat = 0.5,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            config: Config(width: width, cornerRadius: cornerRadius, dividerOpacity: dividerOpacity),
            header: header,
            content: content,
            footer: footer
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            content()
            Divider()
                .opacity(dividerOpacity)
            footer()
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - PaddedScrollContainer.swift"

public enum PaddedScrollContainerCoordinateSpace {
    public static let name = "NolonUI.PaddedScrollContainer"
}

public struct PaddedScrollContainer<Content: View>: View {
    public struct Config {
        public var showsIndicators: Bool
        public var padding: EdgeInsets
        public var maxContentWidth: CGFloat?
        public var contentAlignment: Alignment
        public var minHeight: CGFloat?
        public var maxHeight: CGFloat?

        public init(
            showsIndicators: Bool = true,
            padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            maxContentWidth: CGFloat? = nil,
            contentAlignment: Alignment = .topLeading,
            minHeight: CGFloat? = nil,
            maxHeight: CGFloat? = nil
        ) {
            self.showsIndicators = showsIndicators
            self.padding = padding
            self.maxContentWidth = maxContentWidth
            self.contentAlignment = contentAlignment
            self.minHeight = minHeight
            self.maxHeight = maxHeight
        }
    }

    let showsIndicators: Bool
    let padding: EdgeInsets
    let maxContentWidth: CGFloat?
    let contentAlignment: Alignment
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    let content: () -> Content

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsIndicators = config.showsIndicators
        self.padding = config.padding
        self.maxContentWidth = config.maxContentWidth
        self.contentAlignment = config.contentAlignment
        self.minHeight = config.minHeight
        self.maxHeight = config.maxHeight
        self.content = content
    }

    public init(
        showsIndicators: Bool = true,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        maxContentWidth: CGFloat? = nil,
        contentAlignment: Alignment = .topLeading,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                showsIndicators: showsIndicators,
                padding: padding,
                maxContentWidth: maxContentWidth,
                contentAlignment: contentAlignment,
                minHeight: minHeight,
                maxHeight: maxHeight
            ),
            content: content
        )
    }

    public var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            if let maxContentWidth {
                content()
                    .padding(padding)
                    .frame(maxWidth: maxContentWidth, alignment: contentAlignment)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
            } else {
                content()
                    .padding(padding)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
            }
        }
        .coordinateSpace(name: PaddedScrollContainerCoordinateSpace.name)
        .frame(minHeight: minHeight, maxHeight: maxHeight)
    }
}

// MARK: - UsageSnapshotCardView.swift"

public struct UsageSnapshotCardView<QuotaContent: View>: View {
    public struct Config {
        public var data: UsageSnapshotCardData

        public init(data: UsageSnapshotCardData) {
            self.data = data
        }
    }

    let data: UsageSnapshotCardData
    let quotaContent: () -> QuotaContent

    public init(
        config: Config,
        @ViewBuilder quotaContent: @escaping () -> QuotaContent
    ) {
        self.data = config.data
        self.quotaContent = quotaContent
    }

    public init(
        data: UsageSnapshotCardData,
        @ViewBuilder quotaContent: @escaping () -> QuotaContent
    ) {
        self.init(config: Config(data: data), quotaContent: quotaContent)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch data.body {
            case .success(let footerItems):
                VStack(alignment: .leading, spacing: 12) {
                    quotaContent()
                    footer(items: footerItems)
                }
            case let .error(message, diagnostic, hints):
                errorContent(message: message, diagnostic: diagnostic, hints: hints)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.header.displayName)
                    .font(.headline)

                Spacer()

                Text(data.header.providerLabel)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }

            if let identityLine = data.header.identityLine, !identityLine.isEmpty {
                Text(identityLine)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let accountLine = data.header.accountLine, !accountLine.isEmpty {
                    keyValueRow(
                        title: NSLocalizedString("usage.metric.account", value: "Account", comment: "Account label"),
                        value: accountLine
                    )
                }
                if let planLine = data.header.planLine, !planLine.isEmpty {
                    keyValueRow(
                        title: NSLocalizedString("usage.metric.plan", value: "Plan", comment: "Plan label"),
                        value: planLine
                    )
                }
            }
            .dsTertiaryText(font: .caption)
            .textSelection(.enabled)
        }
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("•")
            Text(value)
        }
    }

    private func footer(items: [String]) -> some View {
        let visibleItems = items.filter { !$0.isEmpty }
        return HStack(spacing: 8) {
            ForEach(Array(visibleItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("•")
                }
                Text(item)
            }
        }
        .font(.caption)
        .dsTertiaryText(font: .caption)
    }

    private func errorContent(message: String, diagnostic: String?, hints: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                .dsErrorText(font: .subheadline)
            Text(message)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .textSelection(.enabled)
            if let diagnostic, !diagnostic.isEmpty {
                Text("diagnostic: \(diagnostic)")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .textSelection(.enabled)
            }
            if !hints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(hints, id: \.self) { hint in
                        Text("• \(hint)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

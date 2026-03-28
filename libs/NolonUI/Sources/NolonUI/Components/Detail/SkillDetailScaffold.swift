import SwiftUI

public enum SkillDetailScaffoldMetrics {
    public static let sidebarWidth: CGFloat = 280
    public static let closeButtonSize: CGFloat = 32
    public static let closeButtonPadding: CGFloat = 16
}

public struct SkillDetailScaffold<Sidebar: View, Content: View>: View {
    public struct Config {
        public var onClose: () -> Void
        public var sidebar: () -> Sidebar
        public var content: () -> Content

        public init(
            onClose: @escaping () -> Void,
            @ViewBuilder sidebar: @escaping () -> Sidebar,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.onClose = onClose
            self.sidebar = sidebar
            self.content = content
        }
    }

    @State private var viewModel = SkillDetailScaffoldViewModel()
    private let onClose: () -> Void
    private let sidebar: Sidebar
    private let content: Content

    public init(config: Config) {
        self.onClose = config.onClose
        self.sidebar = config.sidebar()
        self.content = config.content()
    }

    public init(
        onClose: @escaping () -> Void,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                onClose: onClose,
                sidebar: sidebar,
                content: content
            )
        )
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            SplitLayoutScaffold(
                columnVisibility: $viewModel.columnVisibility,
                profile: SplitLayoutProfiles.skillDetail
            ) {
                sidebar
            } content: {
                EmptyView()
            } detail: {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingCloseButton(
                help: "Close",
                enableCancelShortcut: true,
                action: onClose
            )
            .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
        }
        .background(DesignSystem.Colors.Background.canvas)
        .ignoresSafeArea()
    }
}

public struct SkillDetailSidebarContainer<Content: View, Footer: View>: View {
    public struct Config {
        public var content: () -> Content
        public var footer: () -> Footer

        public init(
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder footer: @escaping () -> Footer
        ) {
            self.content = content
            self.footer = footer
        }
    }

    @State private var viewModel = SkillDetailSidebarContainerViewModel()
    private let content: Content
    private let footer: Footer

    public init(config: Config) {
        self.content = config.content()
        self.footer = config.footer()
    }

    public init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(config: Config(content: content, footer: footer))
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
            footer
        }
        .background(DesignSystem.Colors.Background.elevated)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(DesignSystem.Colors.Component.border.opacity(0.3)),
            alignment: .trailing
        )
    }
}


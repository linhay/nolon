import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - SidebarColumnChrome.swift"

public enum SidebarColumnMetrics {
    public static let headerHeight: CGFloat = 52
    public static let headerHorizontalPadding: CGFloat = 16
    public static let columnMinWidth: CGFloat = 160
    public static let columnIdealWidth: CGFloat = 180
    public static let columnMaxWidth: CGFloat = 200
}

struct SidebarColumnHeader: View {
    @State private var viewModel = SidebarColumnHeaderViewModel()
    let title: String

    struct Config {
        var title: String

        init(title: String) {
            self.title = title
        }
    }

    init(config: Config) {
        self.title = config.title
    }

    init(title: String) {
        self.init(config: Config(title: title))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: SidebarColumnMetrics.headerHeight)
        .padding(.horizontal, SidebarColumnMetrics.headerHorizontalPadding)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.separator)
                .frame(height: 1)
        }
    }
}

// MARK: - SidebarColumnScaffold.swift"

struct SidebarColumnScaffold<Content: View>: View {
    @State private var viewModel = SidebarColumnScaffoldViewModel()
    let title: String
    let showsHeader: Bool
    @ViewBuilder let content: Content

    struct Config {
        var title: String
        var showsHeader: Bool

        init(
            title: String,
            showsHeader: Bool = false
        ) {
            self.title = title
            self.showsHeader = showsHeader
        }
    }

    init(
        config: Config,
        @ViewBuilder content: () -> Content
    ) {
        self.title = config.title
        self.showsHeader = config.showsHeader
        self.content = content()
    }

    init(
        title: String,
        showsHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            config: Config(title: title, showsHeader: showsHeader),
            content: content
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                SidebarColumnHeader(title: title)
            }
            content
        }
        .navigationSplitViewColumnWidth(
            min: SidebarColumnMetrics.columnMinWidth,
            ideal: SidebarColumnMetrics.columnIdealWidth,
            max: SidebarColumnMetrics.columnMaxWidth
        )
    }
}

// MARK: - SidebarTitleHeaderRowView.swift"

public struct SidebarTitleHeaderRowView: View {
    let title: String

    public struct Config {
        public var title: String

        public init(title: String) {
            self.title = title
        }
    }

    public init(config: Config) {
        self.title = config.title
    }

    public init(title: String) {
        self.init(config: Config(title: title))
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            Spacer(minLength: 0)
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.separator)
                .frame(height: 1)
        }
    }
}

// MARK: - SplitLayoutScaffold.swift"

public enum SplitLayoutMode: Sendable {
    case twoColumn
    case threeColumn
}

public enum SplitLayoutChromeStyle: Sendable {
    case standard
    case plain
}

public struct SplitLayoutColumnWidth: Equatable, Sendable {
    public let min: CGFloat
    public let ideal: CGFloat
    public let max: CGFloat

    public init(min: CGFloat, ideal: CGFloat, max: CGFloat) {
        self.min = min
        self.ideal = ideal
        self.max = max
    }
}

public struct SplitLayoutProfile: Equatable, Sendable {
    public let mode: SplitLayoutMode
    public let sidebarWidth: SplitLayoutColumnWidth?
    public let contentWidth: SplitLayoutColumnWidth?
    public let chromeStyle: SplitLayoutChromeStyle

    public init(
        mode: SplitLayoutMode,
        sidebarWidth: SplitLayoutColumnWidth? = nil,
        contentWidth: SplitLayoutColumnWidth? = nil,
        chromeStyle: SplitLayoutChromeStyle = .standard
    ) {
        self.mode = mode
        self.sidebarWidth = sidebarWidth
        self.contentWidth = contentWidth
        self.chromeStyle = chromeStyle
    }
}

public enum SplitLayoutProfiles {
    public static let main = SplitLayoutProfile(mode: .threeColumn)
    public static let accounts = SplitLayoutProfile(mode: .twoColumn)
    public static let skillDetail = SplitLayoutProfile(
        mode: .twoColumn,
        sidebarWidth: .init(min: 280, ideal: 280, max: 280),
        chromeStyle: .plain
    )
    public static let settings = SplitLayoutProfile(
        mode: .twoColumn,
        sidebarWidth: .init(min: 180, ideal: 180, max: 220)
    )

    public static func resourceCenter(isTwoColumn: Bool) -> SplitLayoutProfile {
        SplitLayoutProfile(
            mode: isTwoColumn ? .twoColumn : .threeColumn,
            sidebarWidth: .init(min: 200, ideal: 220, max: 240)
        )
    }
}

public struct SplitLayoutScaffold<
    Sidebar: View,
    Content: View,
    Detail: View
>: View {
    @State private var viewModel = SplitLayoutScaffoldViewModel()
    @Binding private var columnVisibility: NavigationSplitViewVisibility

    private let mode: SplitLayoutMode
    private let sidebarWidth: SplitLayoutColumnWidth?
    private let contentWidth: SplitLayoutColumnWidth?
    private let chromeStyle: SplitLayoutChromeStyle
    private let sidebar: () -> Sidebar
    private let content: () -> Content
    private let detail: () -> Detail

    public struct Config {
        public var mode: SplitLayoutMode
        public var sidebarWidth: SplitLayoutColumnWidth?
        public var contentWidth: SplitLayoutColumnWidth?
        public var chromeStyle: SplitLayoutChromeStyle

        public init(
            mode: SplitLayoutMode,
            sidebarWidth: SplitLayoutColumnWidth? = nil,
            contentWidth: SplitLayoutColumnWidth? = nil,
            chromeStyle: SplitLayoutChromeStyle = .standard
        ) {
            self.mode = mode
            self.sidebarWidth = sidebarWidth
            self.contentWidth = contentWidth
            self.chromeStyle = chromeStyle
        }
    }

    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        config: Config,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self._columnVisibility = columnVisibility
        self.mode = config.mode
        self.sidebarWidth = config.sidebarWidth
        self.contentWidth = config.contentWidth
        self.chromeStyle = config.chromeStyle
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
    }

    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        profile: SplitLayoutProfile,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.init(
            columnVisibility: columnVisibility,
            config: .init(
                mode: profile.mode,
                sidebarWidth: profile.sidebarWidth,
                contentWidth: profile.contentWidth,
                chromeStyle: profile.chromeStyle
            ),
            sidebar: sidebar,
            content: content,
            detail: detail
        )
    }

    public init(
        mode: SplitLayoutMode,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: SplitLayoutColumnWidth? = nil,
        contentWidth: SplitLayoutColumnWidth? = nil,
        chromeStyle: SplitLayoutChromeStyle = .standard,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.init(
            columnVisibility: columnVisibility,
            config: Config(
                mode: mode,
                sidebarWidth: sidebarWidth,
                contentWidth: contentWidth,
                chromeStyle: chromeStyle
            ),
            sidebar: sidebar,
            content: content,
            detail: detail
        )
    }

    public var body: some View {
        Group {
            switch mode {
            case .twoColumn:
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    styledSidebarColumn()
                } detail: {
                    styledDetailColumn()
                }
            case .threeColumn:
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    styledSidebarColumn()
                } content: {
                    styledContentColumn()
                } detail: {
                    styledDetailColumn()
                }
            }
        }
        .background(chromeStyle == .standard ? DesignSystem.Colors.Background.canvas : Color.clear)
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func configuredSidebar() -> some View {
        if let sidebarWidth {
            sidebar().navigationSplitViewColumnWidth(
                min: sidebarWidth.min,
                ideal: sidebarWidth.ideal,
                max: sidebarWidth.max
            )
        } else {
            sidebar()
        }
    }

    @ViewBuilder
    private func configuredContent() -> some View {
        if let contentWidth {
            content().navigationSplitViewColumnWidth(
                min: contentWidth.min,
                ideal: contentWidth.ideal,
                max: contentWidth.max
            )
        } else {
            content()
        }
    }

    private enum SplitLayoutColumnRole {
        case sidebar
        case content
        case detail
    }

    private var separatorColor: Color {
        DesignSystem.Colors.Component.separator.opacity(0.32)
    }

    private func columnBackground(for role: SplitLayoutColumnRole) -> Color {
        switch role {
        case .sidebar:
            return DesignSystem.Colors.Background.elevated
        case .content:
            return DesignSystem.Colors.Background.canvas
        case .detail:
            return DesignSystem.Colors.Background.surface
        }
    }

    @ViewBuilder
    private func applyColumnChrome<Column: View>(
        _ view: Column,
        role: SplitLayoutColumnRole,
        showsTrailingSeparator: Bool
    ) -> some View {
        if chromeStyle == .standard {
            view
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(columnBackground(for: role))
                .overlay(alignment: .trailing) {
                    if showsTrailingSeparator {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(width: 1)
                    }
                }
        } else {
            view
        }
    }

    private func styledSidebarColumn() -> some View {
        applyColumnChrome(
            configuredSidebar(),
            role: .sidebar,
            showsTrailingSeparator: true
        )
    }

    private func styledContentColumn() -> some View {
        applyColumnChrome(
            configuredContent(),
            role: .content,
            showsTrailingSeparator: true
        )
    }

    private func styledDetailColumn() -> some View {
        applyColumnChrome(
            detail(),
            role: .detail,
            showsTrailingSeparator: false
        )
    }
}

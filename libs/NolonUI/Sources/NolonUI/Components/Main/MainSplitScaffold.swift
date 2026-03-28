import SwiftUI

public enum MainSplitScaffoldMetrics {
    public static let overlayAnimationDuration: Double = 0.18
    public static let overlayTransitionScale: CGFloat = 0.98
}

public struct MainSplitScaffold<
    AccountsLayout: View,
    MainLayout: View,
    Overlay: View
>: View {
    public struct Config {
        public var isAccountsSelected: Bool
        public var showsOverlay: Bool
        public var accountsLayout: () -> AccountsLayout
        public var mainLayout: () -> MainLayout
        public var overlay: () -> Overlay

        public init(
            isAccountsSelected: Bool,
            showsOverlay: Bool,
            @ViewBuilder accountsLayout: @escaping () -> AccountsLayout,
            @ViewBuilder mainLayout: @escaping () -> MainLayout,
            @ViewBuilder overlay: @escaping () -> Overlay
        ) {
            self.isAccountsSelected = isAccountsSelected
            self.showsOverlay = showsOverlay
            self.accountsLayout = accountsLayout
            self.mainLayout = mainLayout
            self.overlay = overlay
        }
    }

    @State private var viewModel = MainSplitScaffoldViewModel()
    private let isAccountsSelected: Bool
    private let showsOverlay: Bool
    private let accountsLayout: () -> AccountsLayout
    private let mainLayout: () -> MainLayout
    private let overlay: () -> Overlay

    public init(config: Config) {
        self.isAccountsSelected = config.isAccountsSelected
        self.showsOverlay = config.showsOverlay
        self.accountsLayout = config.accountsLayout
        self.mainLayout = config.mainLayout
        self.overlay = config.overlay
    }

    public init(
        isAccountsSelected: Bool,
        showsOverlay: Bool,
        @ViewBuilder accountsLayout: @escaping () -> AccountsLayout,
        @ViewBuilder mainLayout: @escaping () -> MainLayout,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            config: Config(
                isAccountsSelected: isAccountsSelected,
                showsOverlay: showsOverlay,
                accountsLayout: accountsLayout,
                mainLayout: mainLayout,
                overlay: overlay
            )
        )
    }

    public var body: some View {
        ZStack {
            if isAccountsSelected {
                accountsLayout()
            } else {
                mainLayout()
            }

            if showsOverlay {
                overlay()
                    .transition(.opacity.combined(with: .scale(scale: MainSplitScaffoldMetrics.overlayTransitionScale)))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: MainSplitScaffoldMetrics.overlayAnimationDuration), value: showsOverlay)
    }
}

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
    private let isAccountsSelected: Bool
    private let showsOverlay: Bool
    private let accountsLayout: () -> AccountsLayout
    private let mainLayout: () -> MainLayout
    private let overlay: () -> Overlay

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

@MainActor
private struct MainSplitScaffoldPreviewContainer: View {
    @State private var isAccountsSelected = false
    @State private var showsOverlay = true

    var body: some View {
        MainSplitScaffold(
            isAccountsSelected: isAccountsSelected,
            showsOverlay: showsOverlay
        ) {
            Text("Accounts Layout")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } mainLayout: {
            Text("Main Layout")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 380, height: 200)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Toggle Overlay") {
                    showsOverlay.toggle()
                }
            }
        }
    }
}

#Preview("Main Split Scaffold") {
    MainSplitScaffoldPreviewContainer()
}

import SwiftUI
import NolonUI

enum UIThreeColumnScaffoldMode {
    case twoColumn
    case threeColumn

    fileprivate var nolonUIMode: NolonUI.ThreeColumnScaffoldMode {
        switch self {
        case .twoColumn: return .twoColumn
        case .threeColumn: return .threeColumn
        }
    }
}

struct UIThreeColumnSidebarWidth {
    let min: CGFloat
    let ideal: CGFloat
    let max: CGFloat

    fileprivate var nolonUIWidth: NolonUI.ThreeColumnSidebarWidth {
        .init(min: min, ideal: ideal, max: max)
    }
}

struct UIThreeColumnScaffold<
    Sidebar: View,
    Content: View,
    Detail: View
>: View {
    let mode: UIThreeColumnScaffoldMode
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let sidebarWidth: UIThreeColumnSidebarWidth?
    let sidebar: () -> Sidebar
    let content: () -> Content
    let detail: () -> Detail

    init(
        mode: UIThreeColumnScaffoldMode,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: UIThreeColumnSidebarWidth? = nil,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.mode = mode
        self._columnVisibility = columnVisibility
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
    }

    var body: some View {
        NolonUI.ThreeColumnScaffold(
            mode: mode.nolonUIMode,
            columnVisibility: $columnVisibility,
            sidebarWidth: sidebarWidth?.nolonUIWidth,
            sidebar: sidebar,
            content: content,
            detail: detail
        )
    }
}

struct UIMainSplitScaffold<
    AccountsLayout: View,
    MainLayout: View,
    Overlay: View
>: View {
    let isAccountsSelected: Bool
    let showsOverlay: Bool
    let accountsLayout: () -> AccountsLayout
    let mainLayout: () -> MainLayout
    let overlay: () -> Overlay

    init(
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

    var body: some View {
        NolonUI.MainSplitScaffold(
            isAccountsSelected: isAccountsSelected,
            showsOverlay: showsOverlay,
            accountsLayout: accountsLayout,
            mainLayout: mainLayout,
            overlay: overlay
        )
    }
}

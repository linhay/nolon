import SwiftUI

struct SidebarSectionHeaderView: View {
    let title: String
    let style: ProviderSidebarStyle

    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.labelSmall)
            .foregroundStyle(style.headerColor)
    }
}

#Preview("Sidebar Section Header") {
    SidebarSectionHeaderView(title: "Original Vendors", style: .default)
        .padding()
        .frame(width: 260)
}

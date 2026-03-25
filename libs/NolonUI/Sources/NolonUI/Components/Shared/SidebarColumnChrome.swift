import SwiftUI
import NolonUIFoundation

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

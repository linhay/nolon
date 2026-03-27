import SwiftUI

public struct SidebarTitleHeaderRowView: View {
    let title: String

    public init(title: String) {
        self.title = title
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

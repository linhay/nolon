import SwiftUI
import NolonResourceKit

struct SkillContentToolbar: View {
    let fileName: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Resources")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            
            Text(fileName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(height: 52)
        .background(DesignSystem.Colors.Background.surface.opacity(0.85))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DesignSystem.Colors.Component.border.opacity(0.3)),
            alignment: .bottom
        )
    }
}

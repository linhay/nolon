import SwiftUI
import NolonResourceKit

struct SkillUsageSection: View {
    let scenarios: [String]
    
    var body: some View {
        Group {
            if !scenarios.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Use When".uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .tracking(2.0)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(scenarios, id: \.self) { scenario in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .padding(.top, 8)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                                
                                Text(scenario)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
}

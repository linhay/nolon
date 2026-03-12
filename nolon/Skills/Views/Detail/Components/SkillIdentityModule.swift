import SwiftUI
import NolonResourceKit

struct SkillIdentityModule: View {
    let title: String
    let version: String
    let showsLocalBadge: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                Color(hex: 0x0056b3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Text(title.prefix(1).uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                HStack(spacing: 6) {
                    Text("VERSION \(version)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)

                    if showsLocalBadge {
                        Text(NSLocalizedString("remote.detail.local_badge", comment: "Local badge"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Status.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.Status.success.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

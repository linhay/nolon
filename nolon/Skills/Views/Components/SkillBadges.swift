import SwiftUI

struct SkillVersionBadge: View {
    let version: String

    var body: some View {
        Text("v\(version)")
            .dsBadge(
                foreground: DesignSystem.Colors.Text.primary,
                background: DesignSystem.Colors.Component.controlFillSubtle,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

struct SkillInstalledBadge: View {
    var body: some View {
        Text("Installed")
            .dsBadge(
                foreground: DesignSystem.Colors.Text.onAccent,
                background: DesignSystem.Colors.Status.success,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

struct SkillOrphanedBadge: View {
    var body: some View {
        Text(NSLocalizedString("skill.orphaned", value: "Needs Migration", comment: "Orphaned skill badge"))
            .dsBadge(
                foreground: DesignSystem.Colors.Text.onAccent,
                background: DesignSystem.Colors.Status.warning,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

#Preview {
    HStack {
        SkillVersionBadge(version: "1.0.0")
        SkillInstalledBadge()
    }
    .padding()
}

import SwiftUI

struct SkillVersionBadge: View {
    let version: String

    var body: some View {
        Text("v\(version)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.Component.controlFillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXS, style: .continuous))
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }
}

struct SkillInstalledBadge: View {
    var body: some View {
        Text("Installed")
            .font(.caption2)
            .foregroundStyle(DesignSystem.Colors.Text.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.Status.success)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXS, style: .continuous))
    }
}

struct SkillOrphanedBadge: View {
    var body: some View {
        Text(NSLocalizedString("skill.orphaned", value: "Needs Migration", comment: "Orphaned skill badge"))
            .font(.caption2)
            .foregroundStyle(DesignSystem.Colors.Text.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.Status.warning)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXS, style: .continuous))
    }
}

#Preview {
    HStack {
        SkillVersionBadge(version: "1.0.0")
        SkillInstalledBadge()
    }
    .padding()
}

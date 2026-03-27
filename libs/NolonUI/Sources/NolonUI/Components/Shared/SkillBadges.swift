import SwiftUI

public struct SkillVersionBadge: View {
    @State private var viewModel = SkillVersionBadgeViewModel()
    private let version: String

    public init(version: String) {
        self.version = version
    }

    public var body: some View {
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

public struct SkillInstalledBadge: View {
    @State private var viewModel = SkillInstalledBadgeViewModel()

    public init() {}

    public var body: some View {
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

public struct SkillOrphanedBadge: View {
    @State private var viewModel = SkillOrphanedBadgeViewModel()

    public init() {}

    public var body: some View {
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
        SkillOrphanedBadge()
    }
    .padding()
}

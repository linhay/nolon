import SwiftUI
import NolonResourceKit

/// Left column 3: Skill detail content view
/// Displays the SkillParser structure content for selected skill
@MainActor
public struct SkillDetailContentView: View {
    let skill: Skill?
    let settings: ProviderSettings

    public init(skill: Skill?, settings: ProviderSettings) {
        self.skill = skill
        self.settings = settings
    }

    public var body: some View {
        Group {
            if let skill = skill {
                SkillDetailView(skill: skill, provider: nil, settings: settings)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("detail.no_selection", comment: "No Skill Selected"),
                    systemImage: "doc.text",
                    description: Text(
                        NSLocalizedString(
                            "detail.no_selection_desc",
                            comment: "Select a skill to view its details"))
                        .dsSecondaryText(font: .body)
                )
            }
        }
    }
}

/// Metadata item component
struct MetadataItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .dsSecondaryText(font: .caption)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .dsSecondaryText(font: .caption)

                Text(value)
                    .font(.callout)
            }

            Spacer()
        }
        .padding(8)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM
        )
    }
}

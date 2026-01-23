import MarkdownUI
import SwiftUI

/// Left column 3: Skill detail content view
/// Displays the SkillParser structure content for selected skill
@MainActor
public struct SkillDetailContentView: View {
    let skill: Skill?
    @ObservedObject var settings: ProviderSettings

    public init(skill: Skill?, settings: ProviderSettings) {
        self.skill = skill
        self.settings = settings
    }

    public var body: some View {
        Group {
            if let skill = skill {
                SkillDetailView(skill: skill, settings: settings)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("detail.no_selection", comment: "No Skill Selected"),
                    systemImage: "doc.text",
                    description: Text(
                        NSLocalizedString(
                            "detail.no_selection_desc",
                            comment: "Select a skill to view its details"))
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
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.callout)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (
        size: CGSize, frames: [CGRect]
    ) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}

import SwiftUI
import NolonUIFoundation

public struct GatewayAccountCandidateListView: View {
    let sections: [GatewayAccountCandidateSectionData]
    @Binding var selections: Set<IDBox<UUID>>
    let minHeight: CGFloat

    public init(
        sections: [GatewayAccountCandidateSectionData],
        selections: Binding<Set<IDBox<UUID>>>,
        minHeight: CGFloat = 220
    ) {
        self.sections = sections
        self._selections = selections
        self.minHeight = minHeight
    }

    public var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items, id: \.id) { item in
                        GenericSelectionControl(
                            value: IDBox(item.id),
                            selections: $selections
                        ) { isSelected in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(
                                        isSelected
                                        ? DesignSystem.Colors.primary
                                        : DesignSystem.Colors.Text.tertiary
                                    )
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Label(section.title, systemImage: section.iconName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(sectionForegroundColor(section.tone))
                            .background(
                                sectionBackgroundColor(section.tone),
                                in: Capsule(style: .continuous)
                            )
                        Text("\(section.items.count)")
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
            }
        }
        .frame(minHeight: minHeight)
    }

    private func sectionForegroundColor(_ tone: GatewayCandidateSectionTone) -> Color {
        switch tone {
        case .relay:
            return DesignSystem.Colors.Status.info
        case .openAI:
            return DesignSystem.Colors.primary
        case .premium:
            return DesignSystem.Colors.Status.success
        case .generic:
            return DesignSystem.Colors.Text.secondary
        }
    }

    private func sectionBackgroundColor(_ tone: GatewayCandidateSectionTone) -> Color {
        switch tone {
        case .relay:
            return DesignSystem.Colors.Status.info.opacity(0.14)
        case .openAI:
            return DesignSystem.Colors.primary.opacity(0.14)
        case .premium:
            return DesignSystem.Colors.Status.success.opacity(0.14)
        case .generic:
            return DesignSystem.Colors.Component.controlFillSubtle
        }
    }
}

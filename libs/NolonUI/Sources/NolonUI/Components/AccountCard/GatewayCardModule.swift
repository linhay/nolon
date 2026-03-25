import SwiftUI
import Foundation
import NolonUIFoundation

public struct GatewayCardMemberItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let plan: String?

    public init(id: UUID, title: String, plan: String? = nil) {
        self.id = id
        self.title = title
        self.plan = plan
    }
}

public struct GatewayCardModule: View {
    @State private var viewModel = GatewayCardModuleViewModel()
    public let presentation: AccountCardPresentation
    public let title: String
    public let memberCountText: String
    public let members: [GatewayCardMemberItem]
    public let isCompact: Bool
    public let memberDisplayLimit: Int
    public let memberRowMaxHeight: CGFloat

    public init(
        presentation: AccountCardPresentation = .neutral,
        title: String,
        memberCountText: String,
        members: [GatewayCardMemberItem],
        isCompact: Bool = false,
        memberDisplayLimit: Int = 12,
        memberRowMaxHeight: CGFloat = 70
    ) {
        self.presentation = presentation
        self.title = title
        self.memberCountText = memberCountText
        self.members = members
        self.isCompact = isCompact
        self.memberDisplayLimit = memberDisplayLimit
        self.memberRowMaxHeight = memberRowMaxHeight
    }

    public var body: some View {
        let avatarSize: CGFloat = isCompact ? 16 : 20
        let chipVerticalPadding: CGFloat = isCompact ? 1 : 2
        let chipTrailingPadding: CGFloat = isCompact ? 4 : 6
        let chipSpacing: CGFloat = isCompact ? 4 : 6
        let memberNameFontSize: CGFloat = isCompact ? 9 : 10
        let memberInitialFontSize: CGFloat = isCompact ? 8 : 9

        return AccountSummaryCard(presentation: presentation) {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                HStack(spacing: isCompact ? 8 : 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.15))
                            .frame(width: isCompact ? 20 : 28, height: isCompact ? 20 : 28)
                            .offset(x: isCompact ? 2 : 3, y: isCompact ? -2 : -3)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: isCompact ? 20 : 28, height: isCompact ? 20 : 28)
                            .overlay(
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: isCompact ? 10 : 14))
                                    .foregroundStyle(.white)
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: isCompact ? 13 : 14, weight: isCompact ? .semibold : .bold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        Text(memberCountText)
                            .font(.system(size: isCompact ? 9 : 10, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }

                if !members.isEmpty {
                    FlowLayout(spacing: chipSpacing) {
                        ForEach(members.prefix(memberDisplayLimit)) { member in
                            HStack(spacing: isCompact ? 3 : 4) {
                                if let planInitial = memberPlanInitialText(for: member) {
                                    Text(planInitial)
                                        .font(.system(size: memberInitialFontSize, weight: .bold))
                                        .frame(width: avatarSize, height: avatarSize)
                                        .background(DesignSystem.Colors.primary.opacity(0.12))
                                        .foregroundStyle(DesignSystem.Colors.primary)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: avatarSize, height: avatarSize)
                                }

                                Text(member.title)
                                    .font(.system(size: memberNameFontSize, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.leading, 2)
                            .padding(.trailing, chipTrailingPadding)
                            .padding(.vertical, chipVerticalPadding)
                            .background(DesignSystem.Colors.Background.surface.opacity(0.5))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 0.5)
                            )
                        }

                        if members.count > memberDisplayLimit {
                            Text("+\(members.count - memberDisplayLimit)")
                                .font(.system(size: isCompact ? 8 : 9, weight: .bold))
                                .padding(.horizontal, isCompact ? 5 : 6)
                                .padding(.vertical, isCompact ? 3 : 4)
                                .background(DesignSystem.Colors.Component.controlFillSubtle)
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxHeight: memberRowMaxHeight, alignment: .topLeading)
                    .clipped()
                }
            }
        }
    }

    private func memberPlanInitialText(for member: GatewayCardMemberItem) -> String? {
        if let plan = member.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
           let first = plan.first {
            return String(first).uppercased()
        }
        return nil
    }

}

@MainActor
private struct GatewayCardModulePreviewContainer: View {
    private let mixedMembers: [GatewayCardMemberItem] = [
        .init(id: UUID(), title: "codex-alpha", plan: "Pro"),
        .init(id: UUID(), title: "codex-beta"),
        .init(id: UUID(), title: "relay-eu", plan: "Relay"),
        .init(id: UUID(), title: "relay-us"),
        .init(id: UUID(), title: "backup-gateway", plan: "Team"),
    ]

    private let overflowMembers: [GatewayCardMemberItem] = [
        .init(id: UUID(), title: "alpha", plan: "Pro"),
        .init(id: UUID(), title: "beta"),
        .init(id: UUID(), title: "gamma", plan: "Team"),
        .init(id: UUID(), title: "delta"),
        .init(id: UUID(), title: "epsilon", plan: "Relay"),
        .init(id: UUID(), title: "zeta"),
        .init(id: UUID(), title: "eta", plan: "Pro"),
        .init(id: UUID(), title: "theta"),
        .init(id: UUID(), title: "iota", plan: "Team"),
        .init(id: UUID(), title: "kappa"),
        .init(id: UUID(), title: "lambda", plan: "Relay"),
        .init(id: UUID(), title: "mu"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.section) {
                GatewayCardModule(
                    presentation: .selected,
                    title: "Prod Gateway",
                    memberCountText: "5 个成员",
                    members: mixedMembers,
                    isCompact: false,
                    memberDisplayLimit: 12,
                    memberRowMaxHeight: 70
                )

                GatewayCardModule(
                    presentation: .neutral,
                    title: "Staging Gateway",
                    memberCountText: "5 个成员",
                    members: mixedMembers,
                    isCompact: true,
                    memberDisplayLimit: 8,
                    memberRowMaxHeight: 48
                )

                GatewayCardModule(
                    presentation: .neutral,
                    title: "Gateway with Very Long Name for Truncation Preview",
                    memberCountText: "12 个成员",
                    members: overflowMembers,
                    isCompact: false,
                    memberDisplayLimit: 8,
                    memberRowMaxHeight: 58
                )

                GatewayCardModule(
                    presentation: .pending,
                    title: "Empty Gateway",
                    memberCountText: "0 个成员",
                    members: [],
                    isCompact: false,
                    memberDisplayLimit: 12,
                    memberRowMaxHeight: 70
                )
            }
            .padding(PreviewLayoutTokens.Spacing.page)
        }
        .background(DesignSystem.Colors.Background.canvas)
    }
}

#Preview("Gateway Card Module") {
    GatewayCardModulePreviewContainer()
        .frame(width: 460, height: 760)
}

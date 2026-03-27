import SwiftUI
import NolonUIFoundation

public struct AccountDashboardSectionView<TrendContent: View, RankingContent: View>: View {
    private let dividerColor: Color
    private let trendContent: () -> TrendContent
    private let rankingContent: () -> RankingContent

    public init(
        dividerColor: Color = DesignSystem.Colors.Component.border.opacity(0.35),
        @ViewBuilder trendContent: @escaping () -> TrendContent,
        @ViewBuilder rankingContent: @escaping () -> RankingContent
    ) {
        self.dividerColor = dividerColor
        self.trendContent = trendContent
        self.rankingContent = rankingContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 30) {
                trendContent()
                    .frame(maxWidth: .infinity)
                rankingContent()
                    .frame(width: 320)
            }
        }
        .padding(.top, 4)
    }
}

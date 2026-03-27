import SwiftUI

public struct AccountPanoramaScaffold<Header: View, EmptyState: View, Sections: View, Dashboard: View>: View {
    private let isEmpty: Bool
    private let header: () -> Header
    private let emptyState: () -> EmptyState
    private let sections: () -> Sections
    private let dashboard: () -> Dashboard

    public init(
        isEmpty: Bool,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder emptyState: @escaping () -> EmptyState,
        @ViewBuilder sections: @escaping () -> Sections,
        @ViewBuilder dashboard: @escaping () -> Dashboard
    ) {
        self.isEmpty = isEmpty
        self.header = header
        self.emptyState = emptyState
        self.sections = sections
        self.dashboard = dashboard
    }

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Background.canvas
                .ignoresSafeArea()

            PaddedScrollContainer(
                padding: EdgeInsets(top: 56, leading: 20, bottom: 48, trailing: 20),
                maxContentWidth: 1100,
                contentAlignment: .topLeading
            ) {
                VStack(alignment: .leading, spacing: 58) {
                    header()
                    if isEmpty {
                        emptyState()
                    } else {
                        sections()
                        dashboard()
                    }
                }
            }
        }
    }
}

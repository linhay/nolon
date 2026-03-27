import SwiftUI
import NolonUIFoundation

public struct CodexRuntimeTabContentView<Rows: View>: View {
    let actionsBarData: CodexRuntimeActionsBarData
    let onRefresh: () -> Void
    let processesSectionData: CodexRuntimeProcessesSectionData
    let isProcessesEmpty: Bool
    let rows: () -> Rows

    public init(
        actionsBarData: CodexRuntimeActionsBarData,
        onRefresh: @escaping () -> Void,
        processesSectionData: CodexRuntimeProcessesSectionData,
        isProcessesEmpty: Bool,
        @ViewBuilder rows: @escaping () -> Rows
    ) {
        self.actionsBarData = actionsBarData
        self.onRefresh = onRefresh
        self.processesSectionData = processesSectionData
        self.isProcessesEmpty = isProcessesEmpty
        self.rows = rows
    }

    public var body: some View {
        CodexRuntimeActionsBarView(
            data: actionsBarData,
            onRefresh: onRefresh
        )

        CodexRuntimeProcessesSectionCard(
            data: processesSectionData,
            isEmpty: isProcessesEmpty
        ) {
            if !isProcessesEmpty {
                rows()
            }
        }
    }
}

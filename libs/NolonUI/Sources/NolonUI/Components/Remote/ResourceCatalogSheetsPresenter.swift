import SwiftUI

public struct ResourceCatalogSheetsPresenter<
    Content: View,
    WorkflowItem: Identifiable,
    MCPItem: Identifiable,
    DeleteItem: Identifiable,
    WorkflowSheet: View,
    MCPSheet: View,
    DeleteSheet: View
>: View {
    @Binding var selectedWorkflow: WorkflowItem?
    @Binding var selectedMCP: MCPItem?
    @Binding var deleteRequest: DeleteItem?
    let content: () -> Content
    let workflowSheet: (WorkflowItem) -> WorkflowSheet
    let mcpSheet: (MCPItem) -> MCPSheet
    let deleteSheet: (DeleteItem) -> DeleteSheet

    public init(
        selectedWorkflow: Binding<WorkflowItem?>,
        selectedMCP: Binding<MCPItem?>,
        deleteRequest: Binding<DeleteItem?>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder workflowSheet: @escaping (WorkflowItem) -> WorkflowSheet,
        @ViewBuilder mcpSheet: @escaping (MCPItem) -> MCPSheet,
        @ViewBuilder deleteSheet: @escaping (DeleteItem) -> DeleteSheet
    ) {
        self._selectedWorkflow = selectedWorkflow
        self._selectedMCP = selectedMCP
        self._deleteRequest = deleteRequest
        self.content = content
        self.workflowSheet = workflowSheet
        self.mcpSheet = mcpSheet
        self.deleteSheet = deleteSheet
    }

    public var body: some View {
        content()
            .sheet(item: $selectedWorkflow) { workflow in
                workflowSheet(workflow)
            }
            .sheet(item: $selectedMCP) { mcp in
                mcpSheet(mcp)
            }
            .sheet(item: $deleteRequest) { request in
                deleteSheet(request)
            }
    }
}

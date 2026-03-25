import SwiftUI
import NolonUIFoundation

struct SidebarToolRowView: View {
    @State private var viewModel = SidebarToolRowViewViewModel()
    let item: SidebarToolItem

    var body: some View {
        Label(
            NSLocalizedString(item.titleKey, value: item.fallbackTitle, comment: "Sidebar tool item"),
            systemImage: item.systemImage
        )
        .tag(SidebarSelectionKey(rawValue: item.id.rawValue).rawValue)
    }
}

#Preview("Sidebar Tool Row") {
    List {
        SidebarToolRowView(
            item: SidebarToolItem(
                id: .accounts,
                titleKey: "sidebar.tools.accounts",
                fallbackTitle: "Accounts",
                systemImage: "person.crop.circle.badge.checkmark"
            )
        )
    }
    .listStyle(.sidebar)
    .frame(width: 280, height: 100)
}

import SwiftUI
import NolonUIFoundation

public struct PluginManagementNavigationView: View {
    let data: PluginNavigationData

    public init(data: PluginNavigationData) {
        self.data = data
    }

    public var body: some View {
        List {
            Label(data.itemTitle, systemImage: data.itemSystemImage)
        }
        .listStyle(.sidebar)
        .navigationTitle(data.groupTitle)
    }
}

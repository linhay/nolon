import SwiftUI

public struct GroupedSheetForm<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .sheetScrollContentPadding()
    }
}

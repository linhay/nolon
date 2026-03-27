import SwiftUI

public struct SettingsCardRows<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .dsCard()
    }
}

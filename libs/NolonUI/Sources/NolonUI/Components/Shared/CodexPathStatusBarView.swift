import SwiftUI
import NolonUIFoundation

public struct CodexPathStatusBarView: View {
    let data: CodexPathStatusBarData
    let onConfigure: () -> Void
    let onCheck: () -> Void

    public init(
        data: CodexPathStatusBarData,
        onConfigure: @escaping () -> Void,
        onCheck: @escaping () -> Void
    ) {
        self.data = data
        self.onConfigure = onConfigure
        self.onCheck = onCheck
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                HStack(spacing: 8) {
                    if data.isCheckingPath {
                        ProgressView().controlSize(.small)
                    }
                    if let statusText = data.statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(data.configureTitle) {
                onConfigure()
            }
            .dsPrimaryButton()
            .disabled(data.isConfiguringPath || data.isCheckingPath)

            Button(data.checkTitle) {
                onCheck()
            }
            .dsSecondaryButton()
            .disabled(data.isConfiguringPath || data.isCheckingPath)
        }
    }
}

import SwiftUI
import NolonUIFoundation

public struct SettingsDescriptionToggleActionView: View {
    let data: SettingsDescriptionToggleActionData
    @Binding var toggleValue: Bool
    let isActionDisabled: Bool
    let onActionTap: () -> Void

    public init(
        data: SettingsDescriptionToggleActionData,
        toggleValue: Binding<Bool>,
        isActionDisabled: Bool,
        onActionTap: @escaping () -> Void
    ) {
        self.data = data
        self._toggleValue = toggleValue
        self.isActionDisabled = isActionDisabled
        self.onActionTap = onActionTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.description)
                .font(.caption)
                .dsSecondaryText(font: .caption)

            Toggle(data.toggleTitle, isOn: $toggleValue)

            SettingsActionCardView(data: data.actionCard, onTap: onActionTap)
                .disabled(isActionDisabled)

            if let resultMessage = data.resultMessage, !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            if let errorMessage = data.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .dsErrorText(font: .caption)
            }
        }
    }
}

import SwiftUI

public struct CodexBinaryModelCardView: View {
    let title: String
    let description: String
    let modelLabel: String
    let defaultOptionTitle: String
    let modelOptions: [String]
    @Binding var draftModel: String
    let isSaving: Bool
    let canSave: Bool
    let saveTitle: String
    let statusMessage: String?
    let emptyHint: String?
    let onSave: () -> Void

    public init(
        title: String,
        description: String,
        modelLabel: String,
        defaultOptionTitle: String,
        modelOptions: [String],
        draftModel: Binding<String>,
        isSaving: Bool,
        canSave: Bool,
        saveTitle: String,
        statusMessage: String?,
        emptyHint: String?,
        onSave: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.modelLabel = modelLabel
        self.defaultOptionTitle = defaultOptionTitle
        self.modelOptions = modelOptions
        self._draftModel = draftModel
        self.isSaving = isSaving
        self.canSave = canSave
        self.saveTitle = saveTitle
        self.statusMessage = statusMessage
        self.emptyHint = emptyHint
        self.onSave = onSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Text(description)
                .font(.callout)
                .dsSecondaryText(font: .callout)

            Picker(modelLabel, selection: $draftModel) {
                Text(defaultOptionTitle).tag("")
                ForEach(modelOptions, id: \.self) { slug in
                    Text(slug).tag(slug)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Button(saveTitle, action: onSave)
                    .dsPrimaryButton()
                    .disabled(!canSave || isSaving)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            if let emptyHint, !emptyHint.isEmpty {
                Text(emptyHint)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

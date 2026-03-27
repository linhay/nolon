import SwiftUI

public struct FolderDropPickerCardView: View {
    let displayText: String
    let placeholderText: String
    let hintText: String
    let onTap: () -> Void
    let onDropURLs: ([URL]) -> Bool

    @State private var isDropTargeted = false

    public init(
        displayText: String,
        placeholderText: String,
        hintText: String,
        onTap: @escaping () -> Void,
        onDropURLs: @escaping ([URL]) -> Bool
    ) {
        self.displayText = displayText
        self.placeholderText = placeholderText
        self.hintText = hintText
        self.onTap = onTap
        self.onDropURLs = onDropURLs
    }

    public var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Text(displayText.isEmpty ? placeholderText : displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(
                        displayText.isEmpty
                        ? DesignSystem.Colors.Text.secondary
                        : DesignSystem.Colors.Text.primary
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)

                Text(hintText)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 136)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isDropTargeted
                        ? DesignSystem.Colors.primary.opacity(0.16)
                        : DesignSystem.Colors.Component.controlFillSubtle.opacity(0.92)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isDropTargeted
                        ? DesignSystem.Colors.primary
                        : DesignSystem.Colors.Text.primary.opacity(0.45),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 2)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .inset(by: 4)
                    .strokeBorder(
                        isDropTargeted
                        ? DesignSystem.Colors.primary.opacity(0.95)
                        : DesignSystem.Colors.Text.secondary.opacity(0.95),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                    )
            )
            .shadow(
                color: isDropTargeted
                ? DesignSystem.Colors.primary.opacity(0.45)
                : DesignSystem.Colors.Text.secondary.opacity(0.2),
                radius: isDropTargeted ? 10 : 4
            )
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { items, _ in
            onDropURLs(items)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

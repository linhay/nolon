import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - ContextMenuCommonButtons.swift"

struct ContextMenuViewDetailsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("View Details", comment: "View resource details"), systemImage: "info.circle")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuShowInFinderButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuInstallButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("action.install", value: "Install", comment: "Install action"), systemImage: "arrow.down.circle")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuDeleteButton: View {
    let action: () -> Void
    let isEnabled: Bool

    struct Config {
        var isEnabled: Bool
        var action: () -> Void

        init(
            isEnabled: Bool = true,
            action: @escaping () -> Void
        ) {
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    init(config: Config) {
        self.action = config.action
        self.isEnabled = config.isEnabled
    }

    init(
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(config: Config(isEnabled: isEnabled, action: action))
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), systemImage: "trash")
                .dsIconLabelButton()
        }
        .disabled(!isEnabled)
    }
}

struct ContextMenuDestructiveButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    struct Config {
        var title: String
        var systemImage: String
        var isEnabled: Bool
        var action: () -> Void

        init(
            title: String,
            systemImage: String,
            isEnabled: Bool = true,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.isEnabled = config.isEnabled
        self.action = config.action
    }

    init(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                isEnabled: isEnabled,
                action: action
            )
        )
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: systemImage)
                .dsIconLabelButton()
        }
        .disabled(!isEnabled)
    }
}

// MARK: - EllipsisMenuButton.swift"

struct EllipsisMenuButton<Content: View>: View {
    let iconSize: CGFloat?
    let content: () -> Content

    struct Config {
        var iconSize: CGFloat?

        init(iconSize: CGFloat? = nil) {
            self.iconSize = iconSize
        }
    }

    init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.iconSize = config.iconSize
        self.content = content
    }

    init(
        iconSize: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(config: Config(iconSize: iconSize), content: content)
    }

    var body: some View {
        Menu {
            content()
        } label: {
            if let iconSize {
                Image(systemName: "ellipsis")
                    .dsIconButton(size: iconSize)
            } else {
                Image(systemName: "ellipsis")
                    .dsIconButton()
            }
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - FolderDropPickerCardView.swift"

public struct FolderDropPickerCardView: View {
    let displayText: String
    let placeholderText: String
    let hintText: String
    let onTap: () -> Void
    let onDropURLs: ([URL]) -> Bool

    @State private var isDropTargeted = false

    public struct Config {
        public var displayText: String
        public var placeholderText: String
        public var hintText: String
        public var onTap: () -> Void
        public var onDropURLs: ([URL]) -> Bool

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
    }

    public init(config: Config) {
        self.displayText = config.displayText
        self.placeholderText = config.placeholderText
        self.hintText = config.hintText
        self.onTap = config.onTap
        self.onDropURLs = config.onDropURLs
    }

    public init(
        displayText: String,
        placeholderText: String,
        hintText: String,
        onTap: @escaping () -> Void,
        onDropURLs: @escaping ([URL]) -> Bool
    ) {
        self.init(
            config: Config(
                displayText: displayText,
                placeholderText: placeholderText,
                hintText: hintText,
                onTap: onTap,
                onDropURLs: onDropURLs
            )
        )
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

// MARK: - HighlightedText.swift"

public enum HighlightedTextMatcher {
    public static func matchRanges(text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var currentIndex = lowerText.startIndex
        var ranges: [Range<String.Index>] = []

        for char in lowerQuery {
            guard let range = lowerText.range(
                of: String(char),
                options: .caseInsensitive,
                range: currentIndex..<lowerText.endIndex
            ) else {
                break
            }

            ranges.append(range)
            currentIndex = range.upperBound
        }

        return ranges
    }
}

public struct HighlightedText: View {
    @State private var viewModel = HighlightedTextViewModel()
    private let text: String
    private let query: String
    private let highlightColor: Color

    public struct Config {
        public var text: String
        public var query: String
        public var highlightColor: Color

        public init(
            text: String,
            query: String,
            highlightColor: Color = DesignSystem.Colors.primary
        ) {
            self.text = text
            self.query = query
            self.highlightColor = highlightColor
        }
    }

    public init(config: Config) {
        self.text = config.text
        self.query = config.query
        self.highlightColor = config.highlightColor
    }

    public init(text: String, query: String, highlightColor: Color = DesignSystem.Colors.primary) {
        self.init(
            config: Config(
                text: text,
                query: query,
                highlightColor: highlightColor
            )
        )
    }

    public var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            Text(computeAttributedString())
        }
    }

    private func computeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)

        for range in HighlightedTextMatcher.matchRanges(text: text, query: query) {
            guard
                let start = AttributedString.Index(range.lowerBound, within: attributed),
                let end = AttributedString.Index(range.upperBound, within: attributed)
            else {
                continue
            }

            let attributedRange = start..<end
            attributed[attributedRange].foregroundColor = highlightColor
            attributed[attributedRange].inlinePresentationIntent = .stronglyEmphasized
        }

        return attributed
    }
}

import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - BlockingProgressOverlayView.swift"

public struct BlockingProgressOverlayView: View {
    let message: String

    public struct Config {
        public var message: String

        public init(message: String) {
            self.message = message
        }
    }

    public init(config: Config) {
        self.message = config.message
    }

    public init(message: String) {
        self.init(config: Config(message: message))
    }

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXL, style: .continuous))

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .dsSecondaryText(font: .system(size: 14, weight: .medium))
            }
            .padding(32)
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusL)
        }
    }
}

// MARK: - BottomTrailingOverlayModifier.swift"

private struct BottomTrailingOverlayModifier<Overlay: View>: ViewModifier {
    let isPresented: Bool
    let trailing: CGFloat
    let bottom: CGFloat
    let overlay: () -> Overlay

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isPresented {
                overlay()
                    .padding(.trailing, trailing)
                    .padding(.bottom, bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

public extension View {
    func bottomTrailingOverlay<Overlay: View>(
        isPresented: Bool,
        trailing: CGFloat = 16,
        bottom: CGFloat = 16,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) -> some View {
        modifier(
            BottomTrailingOverlayModifier(
                isPresented: isPresented,
                trailing: trailing,
                bottom: bottom,
                overlay: overlay
            )
        )
    }
}

// MARK: - DismissibleWarningBannerView.swift"

public struct DismissibleWarningBannerView: View {
    let message: String
    let onDismiss: () -> Void

    public struct Config {
        public var message: String
        public var onDismiss: () -> Void

        public init(
            message: String,
            onDismiss: @escaping () -> Void
        ) {
            self.message = message
            self.onDismiss = onDismiss
        }
    }

    public init(config: Config) {
        self.message = config.message
        self.onDismiss = config.onDismiss
    }

    public init(
        message: String,
        onDismiss: @escaping () -> Void
    ) {
        self.init(config: Config(message: message, onDismiss: onDismiss))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.Colors.Status.warning.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignSystem.Colors.Status.warning.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - FloatingCloseButton.swift"

public enum FloatingCloseButtonMetrics {
    public static let iconSystemName = "xmark"
    public static let iconFontSize: CGFloat = 13
    public static let buttonFrameSize: CGFloat = 32
}

public struct FloatingCloseButton: View {
    @State private var viewModel = FloatingCloseButtonViewModel()
    private let help: String
    private let enableCancelShortcut: Bool
    private let action: () -> Void

    public struct Config {
        public var help: String
        public var enableCancelShortcut: Bool
        public var action: () -> Void

        public init(
            help: String = "Close",
            enableCancelShortcut: Bool = true,
            action: @escaping () -> Void
        ) {
            self.help = help
            self.enableCancelShortcut = enableCancelShortcut
            self.action = action
        }
    }

    public init(config: Config) {
        self.help = config.help
        self.enableCancelShortcut = config.enableCancelShortcut
        self.action = config.action
    }

    public init(
        help: String = "Close",
        enableCancelShortcut: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                help: help,
                enableCancelShortcut: enableCancelShortcut,
                action: action
            )
        )
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: FloatingCloseButtonMetrics.iconSystemName)
                .font(.system(size: FloatingCloseButtonMetrics.iconFontSize, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(
                    width: FloatingCloseButtonMetrics.buttonFrameSize,
                    height: FloatingCloseButtonMetrics.buttonFrameSize
                )
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .modifier(FloatingCloseButtonCancelShortcutModifier(isEnabled: enableCancelShortcut))
    }
}

private struct FloatingCloseButtonCancelShortcutModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.keyboardShortcut(.cancelAction)
        } else {
            content
        }
    }
}

// MARK: - OrphanedSkillsMigrationBannerView.swift"

public struct OrphanedSkillsMigrationBannerView: View {
    let title: String
    let description: String
    let actionTitle: String
    let onAction: () -> Void

    public struct Config {
        public var title: String
        public var description: String
        public var actionTitle: String
        public var onAction: () -> Void

        public init(
            title: String,
            description: String,
            actionTitle: String,
            onAction: @escaping () -> Void
        ) {
            self.title = title
            self.description = description
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.description = config.description
        self.actionTitle = config.actionTitle
        self.onAction = config.onAction
    }

    public init(
        title: String,
        description: String,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Spacer()

            Button(actionTitle, action: onAction)
                .dsPrimaryButton()
                .controlSize(.small)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.12),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.35)
        )
    }
}

// MARK: - TopLoadingStatusBannerView.swift"

public struct TopLoadingStatusBannerView: View {
    public let text: String

    public struct Config {
        public var text: String

        public init(text: String) {
            self.text = text
        }
    }

    public init(config: Config) {
        self.text = config.text
    }

    public init(text: String) {
        self.init(config: Config(text: text))
    }

    public var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }
}

// MARK: - UnavailableStateView.swift"

public struct UnavailableStateView: View {
    let title: String
    let systemImage: String
    let description: String?

    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String?

        public init(
            title: String,
            systemImage: String,
            description: String? = nil
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String,
        systemImage: String,
        description: String? = nil
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description
            )
        )
    }

    public var body: some View {
        UnavailableStateScaffold(
            title: title,
            systemImage: systemImage,
            description: description
        ) {
            EmptyView()
        }
    }
}

public struct ActionUnavailableStateView: View {
    let title: String
    let systemImage: String
    let description: String?
    let actionTitle: String
    let onAction: () -> Void

    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String?
        public var actionTitle: String
        public var onAction: () -> Void

        public init(
            title: String,
            systemImage: String,
            description: String? = nil,
            actionTitle: String,
            onAction: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
        self.actionTitle = config.actionTitle
        self.onAction = config.onAction
    }

    public init(
        title: String,
        systemImage: String,
        description: String? = nil,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public var body: some View {
        UnavailableStateScaffold(
            title: title,
            systemImage: systemImage,
            description: description
        ) {
            Button(actionTitle, action: onAction)
                .dsIconLabelButton()
        }
    }
}

private struct UnavailableStateScaffold<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String?
    @ViewBuilder let actions: Actions

    init(
        title: String,
        systemImage: String,
        description: String?,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: systemImage)
                    .dsEmptyStateIcon()
            }
        } description: {
            if let description, !description.isEmpty {
                Text(description)
                    .dsSecondaryText(font: .body)
            }
        } actions: {
            actions
        }
    }
}

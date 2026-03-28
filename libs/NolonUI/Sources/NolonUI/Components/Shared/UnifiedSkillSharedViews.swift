import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - SkillBadges.swift"

public struct SkillVersionBadge: View {
    @State private var viewModel = SkillVersionBadgeViewModel()
    private let version: String

    public struct Config {
        public var version: String

        public init(version: String) {
            self.version = version
        }
    }

    public init(config: Config) {
        self.version = config.version
    }

    public init(version: String) {
        self.init(config: Config(version: version))
    }

    public var body: some View {
        Text("v\(version)")
            .dsBadge(
                foreground: DesignSystem.Colors.Text.primary,
                background: DesignSystem.Colors.Component.controlFillSubtle,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

public struct SkillInstalledBadge: View {
    @State private var viewModel = SkillInstalledBadgeViewModel()

    public struct Config {
        public init() {}
    }

    public init(config: Config) {
        _ = config
    }

    public init() {}

    public var body: some View {
        Text("Installed")
            .dsBadge(
                foreground: DesignSystem.Colors.Text.onAccent,
                background: DesignSystem.Colors.Status.success,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

public struct SkillOrphanedBadge: View {
    @State private var viewModel = SkillOrphanedBadgeViewModel()

    public struct Config {
        public init() {}
    }

    public init(config: Config) {
        _ = config
    }

    public init() {}

    public var body: some View {
        Text(NSLocalizedString("skill.orphaned", value: "Needs Migration", comment: "Orphaned skill badge"))
            .dsBadge(
                foreground: DesignSystem.Colors.Text.onAccent,
                background: DesignSystem.Colors.Status.warning,
                horizontalPadding: 6,
                verticalPadding: 2,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
    }
}

// MARK: - SkillInstallSheetView.swift"

public struct SkillInstallSheetView: View {
    public struct Config {
        public var viewModel: SkillInstallSheetViewModel

        public init(viewModel: SkillInstallSheetViewModel) {
            self.viewModel = viewModel
        }
    }

    @State private var viewModel: SkillInstallSheetViewModel

    public init(config: Config) {
        self._viewModel = State(initialValue: config.viewModel)
    }

    public init(viewModel: SkillInstallSheetViewModel) {
        self.init(config: Config(viewModel: viewModel))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Install", comment: "Install"),
                subtitle: viewModel.data.skillName
            ) {
                viewModel.cancel()
            }

            Divider()

            Form {
                Section {
                    if viewModel.data.providers.isEmpty {
                        Text(NSLocalizedString("No providers available. Please create a local provider first.", comment: "No providers"))
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    } else {
                        Picker(NSLocalizedString("Install to", comment: "Install to"), selection: $viewModel.selectedProviderID) {
                            Text(NSLocalizedString("Select a provider...", comment: "Select provider"))
                                .tag(nil as String?)
                            ForEach(viewModel.data.providers) { provider in
                                if let iconName = provider.iconName {
                                    Label(provider.name, systemImage: iconName)
                                        .tag(provider.id as String?)
                                } else {
                                    Text(provider.name)
                                        .tag(provider.id as String?)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("Select a provider folder where this skill will be installed.", comment: "Install destination"))
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    viewModel.cancel()
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Install", comment: "Install")) {
                    viewModel.confirmInstall()
                }
                .dsPrimaryButton()
                .disabled(viewModel.selectedProviderID == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 280)
    }
}

// MARK: - SkillRowView.swift"

public struct SkillRowView: View {
    @State private var viewModel = SkillRowViewViewModel()
    private let row: SkillRowInfo

    public struct Config {
        public var row: SkillRowInfo

        public init(row: SkillRowInfo) {
            self.row = row
        }
    }

    public init(config: Config) {
        self.row = config.row
    }

    public init(row: SkillRowInfo) {
        self.init(config: Config(row: row))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.name)
                    .font(.headline)

                if row.isInstalled {
                    SkillInstalledBadge()
                }
            }

            Text(row.description)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(2)

            HStack {
                if row.referenceCount > 0 || row.scriptCount > 0 {
                    HStack(spacing: 12) {
                        if row.referenceCount > 0 {
                            Label("\(row.referenceCount)", systemImage: "doc.text")
                                .dsIconLabelText()
                        }
                        if row.scriptCount > 0 {
                            Label("\(row.scriptCount)", systemImage: "terminal")
                                .dsIconLabelText()
                        }
                    }
                }

                Spacer()

                SkillVersionBadge(version: row.version)
            }

            if viewModel.isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("skill.path_label", comment: "Path:"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    Text(row.globalPath)
                        .dsSecondaryText(font: .system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                viewModel.isExpanded.toggle()
            }
        }
    }
}


// MARK: - SkillUpdateRowView.swift"

public struct SkillUpdateRowView: View {
    public let data: SkillUpdateRowData
    public let onUpdate: () -> Void

    public struct Config {
        public var data: SkillUpdateRowData
        public var onUpdate: () -> Void

        public init(
            data: SkillUpdateRowData,
            onUpdate: @escaping () -> Void
        ) {
            self.data = data
            self.onUpdate = onUpdate
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onUpdate = config.onUpdate
    }

    public init(data: SkillUpdateRowData, onUpdate: @escaping () -> Void) {
        self.init(config: Config(data: data, onUpdate: onUpdate))
    }

    public var body: some View {
        HStack(spacing: 16) {
            statusIndicator

            VStack(alignment: .leading, spacing: 4) {
                Text(data.skillName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(data.sourceLabel, systemImage: data.sourceSystemImage)
                        .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .caption)

                    if let currentVersionText = data.currentVersionText {
                        Text(currentVersionText)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }

                    if let latestVersionText = data.latestVersionText {
                        Text(latestVersionText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Status.success)
                    }
                }
            }

            Spacer()

            if data.hasUpdate {
                Button(data.updateButtonTitle) {
                    onUpdate()
                }
                .dsPrimaryButton()
                .controlSize(.small)
            } else {
                Label(data.upToDateText, systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.success)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(data.hasUpdate ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
            .frame(width: 8, height: 8)
    }
}

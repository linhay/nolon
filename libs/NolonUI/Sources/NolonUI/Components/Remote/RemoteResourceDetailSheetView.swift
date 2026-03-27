import SwiftUI
import NolonUIFoundation

public struct RemoteResourceDetailSheetView: View {
    private let data: RemoteResourceDetailData
    private let onInstall: (String) -> Void
    private let onClose: () -> Void

    @State private var selectedProviderID: String?

    public init(
        data: RemoteResourceDetailData,
        onInstall: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.data = data
        self.onInstall = onInstall
        self.onClose = onClose
        _selectedProviderID = State(initialValue: data.preferredProviderID)
    }

    public var body: some View {
        VStack(spacing: 0) {
            NolonUI.SheetHeaderView(
                title: data.title,
                subtitle: data.subtitle
            ) {
                onClose()
            }

            SheetDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !data.stats.isEmpty {
                        statsSection
                    }
                    ForEach(data.sections, id: \.id) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, SheetLayout.horizontalPadding)
                .padding(.vertical, SheetLayout.contentVerticalPadding)
            }

            SheetDivider()

            footer
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(data.stats) { stat in
                    Label(stat.title, systemImage: stat.systemImage)
                        .dsIconLabelText(foreground: statColor(stat), font: .callout)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: RemoteResourceDetailData.Section) -> some View {
        switch section {
        case let .markdown(_, title, content):
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(content)
                        .font(.body)
                        .dsSecondaryText(font: .body)
                }
            }
        case let .codeBlock(_, title, content):
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dsCard(
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                }
            }
        case let .list(_, title, items, monospaced):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.self) { item in
                            Text("• \(item)")
                                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(
                        background: DesignSystem.Colors.Component.controlFillSubtle,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
                }
            }
        case let .kvList(_, title, items, monospaced):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.self) { item in
                            Text(item)
                                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(
                        background: DesignSystem.Colors.Component.controlFillSubtle,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let preferredID = data.preferredProviderID,
               let provider = data.providers.first(where: { $0.id == preferredID }) {
                Text("Install to: \(provider.name)")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            } else {
                Picker("Install to:", selection: $selectedProviderID) {
                    Text("Select Provider").tag(nil as String?)
                    ForEach(data.providers) { provider in
                        Text(provider.name).tag(provider.id as String?)
                    }
                }
                .labelsHidden()
            }

            Spacer()

            Button("Cancel") {
                onClose()
            }
            .dsLinkButton()
            .keyboardShortcut(.cancelAction)

            Button("Install") {
                guard let providerID = data.preferredProviderID ?? selectedProviderID else { return }
                onInstall(providerID)
                onClose()
            }
            .dsPrimaryButton()
            .keyboardShortcut(.defaultAction)
            .disabled((data.preferredProviderID ?? selectedProviderID) == nil)
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }

    private func statColor(_ item: RemoteResourceDetailData.StatItem) -> Color {
        if item.systemImage == "star.fill" {
            return DesignSystem.Colors.Status.warning
        }
        return DesignSystem.Colors.Text.secondary
    }
}

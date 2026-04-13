import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - PluginManagementCardView.swift"

public struct PluginManagementCardView: View {
    let data: PluginManagementCardData
    let onRuntimeAction: () -> Void
    let onLogs: () -> Void
    let onUpgrade: () -> Void
    let onOpenRelease: () -> Void
    let onUninstall: () -> Void

    public struct Config {
        public var data: PluginManagementCardData
        public var onRuntimeAction: () -> Void
        public var onLogs: () -> Void
        public var onUpgrade: () -> Void
        public var onOpenRelease: () -> Void
        public var onUninstall: () -> Void

        public init(
            data: PluginManagementCardData,
            onRuntimeAction: @escaping () -> Void,
            onLogs: @escaping () -> Void,
            onUpgrade: @escaping () -> Void,
            onOpenRelease: @escaping () -> Void,
            onUninstall: @escaping () -> Void
        ) {
            self.data = data
            self.onRuntimeAction = onRuntimeAction
            self.onLogs = onLogs
            self.onUpgrade = onUpgrade
            self.onOpenRelease = onOpenRelease
            self.onUninstall = onUninstall
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onRuntimeAction = config.onRuntimeAction
        self.onLogs = config.onLogs
        self.onUpgrade = config.onUpgrade
        self.onOpenRelease = config.onOpenRelease
        self.onUninstall = config.onUninstall
    }

    public init(
        data: PluginManagementCardData,
        onRuntimeAction: @escaping () -> Void,
        onLogs: @escaping () -> Void,
        onUpgrade: @escaping () -> Void,
        onOpenRelease: @escaping () -> Void,
        onUninstall: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onRuntimeAction: onRuntimeAction,
                onLogs: onLogs,
                onUpgrade: onUpgrade,
                onOpenRelease: onOpenRelease,
                onUninstall: onUninstall
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(data.name, systemImage: "puzzlepiece.extension")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(data.runtimeActionTitle, action: onRuntimeAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!data.runtimeActionEnabled)

                Button(data.logsTitle, action: onLogs)
                    .buttonStyle(.bordered)

                if data.showsUpgradeButton {
                    Button(data.upgradeActionTitle, action: onUpgrade)
                        .dsPrimaryButton()
                        .disabled(!data.upgradeActionEnabled)
                } else {
                    Button(data.openReleaseTitle, action: onOpenRelease)
                        .dsLinkButton()
                }

                if data.showsUninstallButton {
                    Button(data.uninstallActionTitle, action: onUninstall)
                        .buttonStyle(.bordered)
                        .disabled(!data.uninstallActionEnabled)
                }
            }

            HStack(spacing: 14) {
                Text(data.statusText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text(data.installedText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text(data.latestText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Text(data.runtimeStatusText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .textSelection(.enabled)
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}

// MARK: - PluginManagementNavigationView.swift"

public struct PluginManagementNavigationView: View {
    let data: PluginNavigationData

    public struct Config {
        public var data: PluginNavigationData

        public init(data: PluginNavigationData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: PluginNavigationData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        List {
            Label(data.itemTitle, systemImage: data.itemSystemImage)
        }
        .listStyle(.sidebar)
        .navigationTitle(data.groupTitle)
    }
}

// MARK: - PluginRuntimeLogsSheetView.swift"

public struct PluginRuntimeLogsSheetView: View {
    let title: String
    let logs: String
    let emptyText: String
    let autoOnTitle: String
    let autoOffTitle: String
    let clearTitle: String
    let copyTitle: String
    let closeTitle: String
    @Binding var autoScroll: Bool
    let onClear: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    public struct Config {
        public var title: String
        public var logs: String
        public var emptyText: String
        public var autoOnTitle: String
        public var autoOffTitle: String
        public var clearTitle: String
        public var copyTitle: String
        public var closeTitle: String
        public var onClear: () -> Void
        public var onCopy: () -> Void
        public var onClose: () -> Void

        public init(
            title: String = NSLocalizedString("plugin.logs.title", value: "Runtime Logs", comment: "Plugin runtime logs title"),
            logs: String,
            emptyText: String = NSLocalizedString("plugin.logs.empty", value: "No runtime output yet.", comment: "Empty runtime logs"),
            autoOnTitle: String = NSLocalizedString("plugin.logs.auto_on", value: "Auto On", comment: "Auto scroll enabled"),
            autoOffTitle: String = NSLocalizedString("plugin.logs.auto_off", value: "Auto Off", comment: "Auto scroll disabled"),
            clearTitle: String = NSLocalizedString("plugin.logs.clear", value: "Clear", comment: "Clear logs"),
            copyTitle: String = NSLocalizedString("plugin.logs.copy", value: "Copy", comment: "Copy logs"),
            closeTitle: String = NSLocalizedString("plugin.logs.close", value: "Close", comment: "Close logs sheet"),
            onClear: @escaping () -> Void,
            onCopy: @escaping () -> Void,
            onClose: @escaping () -> Void
        ) {
            self.title = title
            self.logs = logs
            self.emptyText = emptyText
            self.autoOnTitle = autoOnTitle
            self.autoOffTitle = autoOffTitle
            self.clearTitle = clearTitle
            self.copyTitle = copyTitle
            self.closeTitle = closeTitle
            self.onClear = onClear
            self.onCopy = onCopy
            self.onClose = onClose
        }
    }

    public init(
        autoScroll: Binding<Bool>,
        config: Config
    ) {
        self.title = config.title
        self.logs = config.logs
        self.emptyText = config.emptyText
        self.autoOnTitle = config.autoOnTitle
        self.autoOffTitle = config.autoOffTitle
        self.clearTitle = config.clearTitle
        self.copyTitle = config.copyTitle
        self.closeTitle = config.closeTitle
        self._autoScroll = autoScroll
        self.onClear = config.onClear
        self.onCopy = config.onCopy
        self.onClose = config.onClose
    }

    public init(
        title: String = NSLocalizedString("plugin.logs.title", value: "Runtime Logs", comment: "Plugin runtime logs title"),
        logs: String,
        emptyText: String = NSLocalizedString("plugin.logs.empty", value: "No runtime output yet.", comment: "Empty runtime logs"),
        autoOnTitle: String = NSLocalizedString("plugin.logs.auto_on", value: "Auto On", comment: "Auto scroll enabled"),
        autoOffTitle: String = NSLocalizedString("plugin.logs.auto_off", value: "Auto Off", comment: "Auto scroll disabled"),
        clearTitle: String = NSLocalizedString("plugin.logs.clear", value: "Clear", comment: "Clear logs"),
        copyTitle: String = NSLocalizedString("plugin.logs.copy", value: "Copy", comment: "Copy logs"),
        closeTitle: String = NSLocalizedString("plugin.logs.close", value: "Close", comment: "Close logs sheet"),
        autoScroll: Binding<Bool>,
        onClear: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.init(
            autoScroll: autoScroll,
            config: Config(
                title: title,
                logs: logs,
                emptyText: emptyText,
                autoOnTitle: autoOnTitle,
                autoOffTitle: autoOffTitle,
                clearTitle: clearTitle,
                copyTitle: copyTitle,
                closeTitle: closeTitle,
                onClear: onClear,
                onCopy: onCopy,
                onClose: onClose
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(autoScroll ? autoOnTitle : autoOffTitle) {
                    autoScroll.toggle()
                }
                .buttonStyle(.bordered)
                Button(clearTitle) {
                    onClear()
                }
                .buttonStyle(.bordered)
                Button(copyTitle) {
                    onCopy()
                }
                .buttonStyle(.bordered)
                Button(closeTitle) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logs.isEmpty ? emptyText : logs)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Color.clear
                        .frame(height: 1)
                        .id("runtime-log-bottom")
                }
                .onAppear {
                    guard autoScroll else { return }
                    Task { @MainActor in
                        proxy.scrollTo("runtime-log-bottom", anchor: .bottom)
                    }
                }
                .onChange(of: logs) { _, _ in
                    guard autoScroll else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("runtime-log-bottom", anchor: .bottom)
                    }
                }
                .dsCard(
                    background: DesignSystem.Colors.Background.surface,
                    cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.3)
                )
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 420)
    }
}

// MARK: - InstallProviderSelectionSheet.swift"

public struct InstallProviderSelectionSheet: View {
    public struct Config {
        public var isPresented: Binding<Bool>
        public var itemName: String
        public var providers: [SkillInstallProviderOption]
        public var onConfirm: (String) -> Void

        public init(
            isPresented: Binding<Bool>,
            itemName: String,
            providers: [SkillInstallProviderOption],
            onConfirm: @escaping (String) -> Void
        ) {
            self.isPresented = isPresented
            self.itemName = itemName
            self.providers = providers
            self.onConfirm = onConfirm
        }
    }

    @Binding var isPresented: Bool
    let itemName: String
    let providers: [SkillInstallProviderOption]
    let onConfirm: (String) -> Void

    public init(config: Config) {
        self._isPresented = config.isPresented
        self.itemName = config.itemName
        self.providers = config.providers
        self.onConfirm = config.onConfirm
    }

    public init(
        isPresented: Binding<Bool>,
        itemName: String,
        providers: [SkillInstallProviderOption],
        onConfirm: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                isPresented: isPresented,
                itemName: itemName,
                providers: providers,
                onConfirm: onConfirm
            )
        )
    }

    public var body: some View {
        SkillInstallSheetView(
            config: .init(
                viewModel: SkillInstallSheetViewModel(
                    data: .init(
                        skillName: itemName,
                        providers: providers
                    ),
                    onConfirm: { providerID in
                        onConfirm(providerID)
                        isPresented = false
                    },
                    onCancel: {
                        isPresented = false
                    }
                )
            )
        )
    }
}

// MARK: - InstallProviderSelectionSheetModifier.swift"

public extension View {
    func installProviderSelectionSheet(
        isPresented: Binding<Bool>,
        itemName: String,
        providers: [SkillInstallProviderOption],
        onSelectProviderID: @escaping (String) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            InstallProviderSelectionSheet(
                isPresented: isPresented,
                itemName: itemName,
                providers: providers,
                onConfirm: onSelectProviderID
            )
        }
    }
}

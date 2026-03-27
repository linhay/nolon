import SwiftUI

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
        self.title = title
        self.logs = logs
        self.emptyText = emptyText
        self.autoOnTitle = autoOnTitle
        self.autoOffTitle = autoOffTitle
        self.clearTitle = clearTitle
        self.copyTitle = copyTitle
        self.closeTitle = closeTitle
        self._autoScroll = autoScroll
        self.onClear = onClear
        self.onCopy = onCopy
        self.onClose = onClose
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

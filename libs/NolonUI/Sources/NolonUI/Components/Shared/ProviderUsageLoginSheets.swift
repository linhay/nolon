import SwiftUI
import WebKit

public struct UsageLoginSheetView: View {
    let title: String
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    public init(title: String, url: URL?) {
        self.title = title
        self.url = url
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title) {
                dismiss()
            }

            SheetDivider()

            if let url {
                ProviderLoginWebView(url: url)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in"),
                    systemImage: "globe",
                    description: Text(NSLocalizedString("usage.monitor.unsupported.desc", value: "Usage is not configured for this provider yet.", comment: "Unsupported"))
                        .dsSecondaryText(font: .body)
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

public struct ProviderLoginWebView: NSViewRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.load(URLRequest(url: url))
        return view
    }

    public func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}

public struct CodexLoginURLSheetView: View {
    let mode: String
    let url: URL?
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    public static var dismissActionTitle: String {
        NSLocalizedString("codex.login.sheet.cancel", value: "取消登录", comment: "Cancel login")
    }

    public init(
        mode: String,
        url: URL?,
        onCopy: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.url = url
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("codex.login.sheet.title", value: "登录中", comment: "Codex login sheet title"))
                    .font(.headline)
                Spacer()
                Button(Self.dismissActionTitle) {
                    onCancel()
                    dismiss()
                }
            }

            Text(mode)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            GroupBox {
                Text(url?.absoluteString ?? "-")
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(NSLocalizedString("codex.login.sheet.copy", value: "复制 URL", comment: "Copy login URL")) {
                    onCopy()
                }
                Button(NSLocalizedString("codex.login.sheet.open", value: "在浏览器中打开", comment: "Open in browser")) {
                    onOpen()
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 220)
    }
}

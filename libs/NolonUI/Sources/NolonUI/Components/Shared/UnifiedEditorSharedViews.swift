import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - CodeEditorSheetView.swift"

public struct CodeEditorSheetView: View {
    let title: String
    let initialText: String
    let initialTextLoader: (() async -> String)?
    let highlight: WebCodeEditorHighlight?
    let invalidAlertTitle: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let cancelTitle: String
    let saveTitle: String
    let okTitle: String
    let onValidate: (String) throws -> Void
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var bridge = WebCodeEditorBridge()
    @State private var isDirty = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var loadedInitialText: String
    @State private var hasRequestedInitialLoad = false

    public struct Config {
        public var title: String
        public var initialText: String
        public var initialTextLoader: (() async -> String)?
        public var highlight: WebCodeEditorHighlight?
        public var invalidAlertTitle: String
        public var minWidth: CGFloat
        public var minHeight: CGFloat
        public var cancelTitle: String
        public var saveTitle: String
        public var okTitle: String
        public var onValidate: (String) throws -> Void
        public var onSave: (String) async throws -> Void

        public init(
            title: String,
            initialText: String = "",
            initialTextLoader: (() async -> String)? = nil,
            highlight: WebCodeEditorHighlight?,
            invalidAlertTitle: String = NSLocalizedString(
                "generic.error",
                value: "Error",
                comment: "Generic error title"
            ),
            minWidth: CGFloat = 760,
            minHeight: CGFloat = 560,
            cancelTitle: String = NSLocalizedString(
                "action.cancel",
                value: "Cancel",
                comment: "Cancel"
            ),
            saveTitle: String = NSLocalizedString(
                "action.save",
                value: "Save",
                comment: "Save"
            ),
            okTitle: String = NSLocalizedString(
                "generic.ok",
                value: "OK",
                comment: "OK"
            ),
            onValidate: @escaping (String) throws -> Void,
            onSave: @escaping (String) async throws -> Void
        ) {
            self.title = title
            self.initialText = initialText
            self.initialTextLoader = initialTextLoader
            self.highlight = highlight
            self.invalidAlertTitle = invalidAlertTitle
            self.minWidth = minWidth
            self.minHeight = minHeight
            self.cancelTitle = cancelTitle
            self.saveTitle = saveTitle
            self.okTitle = okTitle
            self.onValidate = onValidate
            self.onSave = onSave
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.initialText = config.initialText
        self.initialTextLoader = config.initialTextLoader
        self.highlight = config.highlight
        self.invalidAlertTitle = config.invalidAlertTitle
        self.minWidth = config.minWidth
        self.minHeight = config.minHeight
        self.cancelTitle = config.cancelTitle
        self.saveTitle = config.saveTitle
        self.okTitle = config.okTitle
        self.onValidate = config.onValidate
        self.onSave = config.onSave
        self._loadedInitialText = State(initialValue: config.initialText)
    }

    public init(
        title: String,
        initialText: String = "",
        initialTextLoader: (() async -> String)? = nil,
        highlight: WebCodeEditorHighlight?,
        invalidAlertTitle: String = NSLocalizedString(
            "generic.error",
            value: "Error",
            comment: "Generic error title"
        ),
        minWidth: CGFloat = 760,
        minHeight: CGFloat = 560,
        cancelTitle: String = NSLocalizedString(
            "action.cancel",
            value: "Cancel",
            comment: "Cancel"
        ),
        saveTitle: String = NSLocalizedString(
            "action.save",
            value: "Save",
            comment: "Save"
        ),
        okTitle: String = NSLocalizedString(
            "generic.ok",
            value: "OK",
            comment: "OK"
        ),
        onValidate: @escaping (String) throws -> Void,
        onSave: @escaping (String) async throws -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                initialText: initialText,
                initialTextLoader: initialTextLoader,
                highlight: highlight,
                invalidAlertTitle: invalidAlertTitle,
                minWidth: minWidth,
                minHeight: minHeight,
                cancelTitle: cancelTitle,
                saveTitle: saveTitle,
                okTitle: okTitle,
                onValidate: onValidate,
                onSave: onSave
            )
        )
    }

    public var body: some View {
        NavigationStack {
            WebCodeEditorView(
                bridge: bridge,
                initialText: loadedInitialText,
                highlight: highlight,
                onDirtyChanged: { isDirty = $0 }
            )
            .background(DesignSystem.Colors.Background.surface)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        Task { await saveDraft() }
                    }
                    .disabled(!isDirty || isSaving)
                }
            }
            .alert(
                invalidAlertTitle,
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button(okTitle) {}
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
        .task(id: loadedInitialText) {
            bridge.setText(loadedInitialText)
            bridge.setHighlight(highlight)
        }
        .task {
            guard !hasRequestedInitialLoad, let initialTextLoader else {
                return
            }
            hasRequestedInitialLoad = true
            let loadedText = await initialTextLoader()
            if loadedText != loadedInitialText {
                loadedInitialText = loadedText
            }
        }
    }

    private func saveDraft() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let text = try await bridge.requestText()
            try onValidate(text)
            try await onSave(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - DirectoryPickerSheetView.swift"

public struct DirectoryPickerSheetView: View {
    @State private var viewModel: DirectoryPickerSheetViewModel

    public struct Config {
        public var viewModel: DirectoryPickerSheetViewModel

        public init(viewModel: DirectoryPickerSheetViewModel) {
            self.viewModel = viewModel
        }
    }

    public init(config: Config) {
        self._viewModel = State(initialValue: config.viewModel)
    }

    public init(viewModel: DirectoryPickerSheetViewModel) {
        self.init(config: Config(viewModel: viewModel))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Choose Skills Directories", comment: "Choose skills directories"),
                subtitle: NSLocalizedString("Select one or more directories containing skills:", comment: "Select directories")
            ) {
                viewModel.cancel()
            }

            Divider()

            Form {
                Section {
                    ForEach(viewModel.data.candidates) { candidate in
                        Button {
                            viewModel.toggleSelection(candidate.id)
                        } label: {
                            row(candidate: candidate, isSelected: viewModel.selectedIDs.contains(candidate.id))
                        }
                        .buttonStyle(.plain)
                    }
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

                Button(NSLocalizedString("select", comment: "Select")) {
                    viewModel.confirm()
                }
                .dsPrimaryButton()
                .disabled(viewModel.selectedIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 400)
    }

    @ViewBuilder
    private func row(candidate: DirectoryPickerCandidateInfo, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
                Text(candidate.path == "."
                    ? NSLocalizedString("Repository Root", comment: "Repository root")
                    : candidate.path)
                    .font(.body)
                Spacer(minLength: 0)
                Text("\(candidate.skillCount) skill\(candidate.skillCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            if !candidate.skillNames.isEmpty {
                Text(candidate.skillNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
                    .padding(.leading, 20)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - FileBackedCodeEditorSheetView.swift"

public struct FileBackedCodeEditorSheetView: View {
    let title: String
    let fileURL: URL
    let highlight: WebCodeEditorHighlight?
    let invalidAlertTitle: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let onValidate: (String) throws -> Void
    let onAfterSave: ((String) async -> Void)?

    public struct Config {
        public var title: String
        public var fileURL: URL
        public var highlight: WebCodeEditorHighlight?
        public var invalidAlertTitle: String
        public var minWidth: CGFloat
        public var minHeight: CGFloat
        public var onValidate: (String) throws -> Void
        public var onAfterSave: ((String) async -> Void)?

        public init(
            title: String,
            fileURL: URL,
            highlight: WebCodeEditorHighlight?,
            invalidAlertTitle: String = NSLocalizedString(
                "generic.error",
                value: "Error",
                comment: "Generic error title"
            ),
            minWidth: CGFloat = 760,
            minHeight: CGFloat = 560,
            onValidate: @escaping (String) throws -> Void,
            onAfterSave: ((String) async -> Void)? = nil
        ) {
            self.title = title
            self.fileURL = fileURL
            self.highlight = highlight
            self.invalidAlertTitle = invalidAlertTitle
            self.minWidth = minWidth
            self.minHeight = minHeight
            self.onValidate = onValidate
            self.onAfterSave = onAfterSave
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.fileURL = config.fileURL
        self.highlight = config.highlight
        self.invalidAlertTitle = config.invalidAlertTitle
        self.minWidth = config.minWidth
        self.minHeight = config.minHeight
        self.onValidate = config.onValidate
        self.onAfterSave = config.onAfterSave
    }

    public init(
        title: String,
        fileURL: URL,
        highlight: WebCodeEditorHighlight?,
        invalidAlertTitle: String = NSLocalizedString(
            "generic.error",
            value: "Error",
            comment: "Generic error title"
        ),
        minWidth: CGFloat = 760,
        minHeight: CGFloat = 560,
        onValidate: @escaping (String) throws -> Void,
        onAfterSave: ((String) async -> Void)? = nil
    ) {
        self.init(
            config: Config(
                title: title,
                fileURL: fileURL,
                highlight: highlight,
                invalidAlertTitle: invalidAlertTitle,
                minWidth: minWidth,
                minHeight: minHeight,
                onValidate: onValidate,
                onAfterSave: onAfterSave
            )
        )
    }

    public var body: some View {
        CodeEditorSheetView(
            title: title,
            initialTextLoader: {
                (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            },
            highlight: highlight,
            invalidAlertTitle: invalidAlertTitle,
            minWidth: minWidth,
            minHeight: minHeight,
            onValidate: onValidate,
            onSave: { text in
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                await onAfterSave?(text)
            }
        )
    }
}

// MARK: - TokenInputSheetView.swift"

public struct TokenInputSheetView: View {
    @Binding var isPresented: Bool
    let host: String
    @Binding var token: String
    let onConfirm: () -> Void

    public struct Config {
        public var host: String
        public var onConfirm: () -> Void

        public init(
            host: String,
            onConfirm: @escaping () -> Void
        ) {
            self.host = host
            self.onConfirm = onConfirm
        }
    }

    public init(
        isPresented: Binding<Bool>,
        token: Binding<String>,
        config: Config
    ) {
        self._isPresented = isPresented
        self.host = config.host
        self._token = token
        self.onConfirm = config.onConfirm
    }

    public init(
        isPresented: Binding<Bool>,
        host: String,
        token: Binding<String>,
        onConfirm: @escaping () -> Void
    ) {
        self.init(
            isPresented: isPresented,
            token: token,
            config: Config(host: host, onConfirm: onConfirm)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("SSH Authentication Unavailable", comment: "SSH unavailable")) {
                isPresented = false
            }

            SheetDivider()

            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.Status.warning)

                Text(
                    String(
                        format: NSLocalizedString(
                            "SSH key is not configured for %@. Please provide a Personal Access Token to authenticate.",
                            comment: "SSH token prompt"
                        ),
                        host
                    )
                )
                .font(.subheadline)
                .dsSecondaryText(font: .subheadline)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Personal Access Token", comment: "Personal access token"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    SecureField(NSLocalizedString("Enter your token", comment: "Enter token"), text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text(NSLocalizedString("Generate a token from your Git provider's settings with 'read_repository' scope.", comment: "Token help"))
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.vertical, SheetLayout.contentVerticalPadding)

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Save & Retry", comment: "Save and retry")) {
                    isPresented = false
                    onConfirm()
                }
                .dsPrimaryButton()
                .disabled(token.isEmpty)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420)
    }
}

// MARK: - WebCodeEditorView.swift"

@MainActor
public final class WebCodeEditorBridge {
    fileprivate weak var webView: WKWebView?
    fileprivate var isReady = false
    fileprivate var pendingText: String?
    fileprivate var pendingHighlight: WebCodeEditorHighlight?

    public init() {}

    public func setText(_ text: String) {
        if isReady {
            applyText(text)
        } else {
            pendingText = text
        }
    }

    public func setHighlight(_ highlight: WebCodeEditorHighlight?) {
        if isReady {
            applyHighlight(highlight)
        } else {
            pendingHighlight = highlight
        }
    }

    public func requestText() async throws -> String {
        guard let webView else { return "" }
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript("window.__nolon?.getText?.()") { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? String ?? "")
                }
            }
        }
    }

    fileprivate func markReady() {
        isReady = true
        if let pendingText {
            applyText(pendingText)
            self.pendingText = nil
        }
        if let pendingHighlight {
            applyHighlight(pendingHighlight)
            self.pendingHighlight = nil
        } else {
            applyHighlight(nil)
        }
    }

    private func applyText(_ text: String) {
        guard let webView else { return }
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        webView.evaluateJavaScript("window.__nolon?.setText?.(`\(escaped)`);")
    }

    private func applyHighlight(_ highlight: WebCodeEditorHighlight?) {
        guard let webView else { return }
        if let highlight {
            let keyEscaped = highlight.key
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            webView.evaluateJavaScript("window.__nolon?.setHighlight?.({format: \"\(highlight.format.rawValue)\", key: \"\(keyEscaped)\"});")
        } else {
            webView.evaluateJavaScript("window.__nolon?.setHighlight?.(null);")
        }
    }
}

public enum WebCodeEditorFormat: String, Sendable {
    case json
    case toml
}

public struct WebCodeEditorHighlight: Sendable {
    public let format: WebCodeEditorFormat
    public let key: String

    public init(format: WebCodeEditorFormat, key: String) {
        self.format = format
        self.key = key
    }
}

public struct WebCodeEditorView: NSViewRepresentable {
    public let bridge: WebCodeEditorBridge
    public let initialText: String
    public let highlight: WebCodeEditorHighlight?
    public let onDirtyChanged: (Bool) -> Void

    public struct Config {
        public var initialText: String
        public var highlight: WebCodeEditorHighlight?
        public var onDirtyChanged: (Bool) -> Void

        public init(
            initialText: String,
            highlight: WebCodeEditorHighlight?,
            onDirtyChanged: @escaping (Bool) -> Void
        ) {
            self.initialText = initialText
            self.highlight = highlight
            self.onDirtyChanged = onDirtyChanged
        }
    }

    public init(
        bridge: WebCodeEditorBridge,
        config: Config
    ) {
        self.bridge = bridge
        self.initialText = config.initialText
        self.highlight = config.highlight
        self.onDirtyChanged = config.onDirtyChanged
    }

    public init(
        bridge: WebCodeEditorBridge,
        initialText: String,
        highlight: WebCodeEditorHighlight?,
        onDirtyChanged: @escaping (Bool) -> Void
    ) {
        self.init(
            bridge: bridge,
            config: Config(
                initialText: initialText,
                highlight: highlight,
                onDirtyChanged: onDirtyChanged
            )
        )
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "nolon")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator

        bridge.webView = webView
        bridge.setText(initialText)
        bridge.setHighlight(highlight)

        webView.loadHTMLString(Self.html, baseURL: nil)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        bridge.setHighlight(highlight)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge, onDirtyChanged: onDirtyChanged)
    }

    public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let bridge: WebCodeEditorBridge
        private let onDirtyChanged: (Bool) -> Void

        init(bridge: WebCodeEditorBridge, onDirtyChanged: @escaping (Bool) -> Void) {
            self.bridge = bridge
            self.onDirtyChanged = onDirtyChanged
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.markReady()
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String
            else { return }

            switch type {
            case "dirty":
                onDirtyChanged(payload["value"] as? Bool ?? false)
            default:
                break
            }
        }
    }

    private static let html = """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          :root {
            --font: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            --bg: rgba(0,0,0,0.0);
            --text: #111;
            --selection: rgba(10,132,255,0.25);
            --highlight: rgba(255, 204, 0, 0.25);
            --gutter: rgba(60,60,67,0.18);
            --gutterText: rgba(60,60,67,0.60);
            --gutterWidth: 56px;
          }

          @media (prefers-color-scheme: dark) {
            :root {
              --text: #f5f5f7;
              --selection: rgba(10,132,255,0.35);
              --highlight: rgba(255, 214, 10, 0.22);
              --gutter: rgba(235,235,245,0.18);
              --gutterText: rgba(235,235,245,0.60);
            }
          }

          html, body {
            height: 100%;
            margin: 0;
            background: var(--bg);
            overflow: hidden;
          }

          #wrap {
            position: relative;
            height: 100%;
          }

          #gutter, #overlay, #editor {
            box-sizing: border-box;
            position: absolute;
            inset: 0;
            font-family: var(--font);
            font-size: 12px;
            line-height: 18px;
            tab-size: 4;
            white-space: pre;
            margin: 0;
          }

          #gutter {
            left: 0;
            right: auto;
            width: var(--gutterWidth);
            padding: 14px 10px 14px 0;
            overflow: auto;
            pointer-events: none;
            text-align: right;
            color: var(--gutterText);
            border-right: 1px solid var(--gutter);
          }

          #overlay {
            left: 0;
            overflow: auto;
            pointer-events: none;
          }

          #overlayContent {
            position: relative;
            min-height: 100%;
            min-width: 100%;
          }

          #highlightBlock {
            position: absolute;
            background: var(--highlight);
            border-radius: 6px;
          }

          #editor {
            color: var(--text);
            -webkit-text-fill-color: var(--text);
            background: transparent;
            border: none;
            outline: none;
            resize: none;
            caret-color: var(--text);
            overflow: auto;
            padding: 14px 16px 14px calc(16px + var(--gutterWidth));
          }

          #editor::selection {
            background: var(--selection);
          }

          #gutter::-webkit-scrollbar,
          #overlay::-webkit-scrollbar,
          #editor::-webkit-scrollbar {
            width: 0;
            height: 0;
          }
        </style>
      </head>
      <body>
        <div id="wrap">
          <pre id="gutter"></pre>
          <div id="overlay"><div id="overlayContent"><div id="highlightBlock"></div></div></div>
          <textarea id="editor" spellcheck="false" wrap="off"></textarea>
        </div>
        <script>
          const editor = document.getElementById('editor');
          const gutter = document.getElementById('gutter');
          const overlay = document.getElementById('overlay');
          const overlayContent = document.getElementById('overlayContent');
          const highlightBlock = document.getElementById('highlightBlock');

          let dirty = false;
          let highlightSpec = null;

          function postDirty(value) {
            try {
              window.webkit.messageHandlers.nolon.postMessage({ type: 'dirty', value });
            } catch (_) {}
          }

          function isWhitespace(ch) {
            return ch === ' ' || ch === '\\n' || ch === '\\t' || ch === '\\r';
          }

          function findMatching(text, startIndex, openChar, closeChar) {
            let depth = 0;
            let inString = false;
            let escaped = false;
            for (let i = startIndex; i < text.length; i++) {
              const ch = text[i];
              if (inString) {
                if (escaped) {
                  escaped = false;
                } else if (ch === '\\\\') {
                  escaped = true;
                } else if (ch === '\"') {
                  inString = false;
                }
                continue;
              }
              if (ch === '\"') {
                inString = true;
                continue;
              }
              if (ch === openChar) depth++;
              if (ch === closeChar) {
                depth--;
                if (depth === 0) return i;
              }
            }
            return -1;
          }

          function parseJsonValueRange(text, startIndex) {
            let i = startIndex;
            while (i < text.length && isWhitespace(text[i])) i++;
            const ch = text[i];
            if (ch === '{') {
              const end = findMatching(text, i, '{', '}');
              if (end >= 0) return { start: i, end: end + 1 };
            }
            if (ch === '[') {
              const end = findMatching(text, i, '[', ']');
              if (end >= 0) return { start: i, end: end + 1 };
            }
            if (ch === '\"') {
              let inString = true;
              let escaped = false;
              for (let j = i + 1; j < text.length; j++) {
                const c = text[j];
                if (escaped) {
                  escaped = false;
                } else if (c === '\\\\') {
                  escaped = true;
                } else if (c === '\"') {
                  inString = false;
                  return { start: i, end: j + 1 };
                }
              }
            }
            for (let j = i; j < text.length; j++) {
              const c = text[j];
              if (c === ',' || c === '}' || c === ']' || c === '\\n' || c === '\\r') {
                return { start: i, end: j };
              }
            }
            return { start: i, end: text.length };
          }

          function findJsonMcpServerRange(text, key) {
            const quotedKey = '\"' + key.replaceAll('\"', '\\\\\"') + '\"';
            const serversKeyIndex =
              text.indexOf('\"mcpServers\"') >= 0 ? text.indexOf('\"mcpServers\"') : text.indexOf('\"mcp_servers\"');
            if (serversKeyIndex < 0) return null;

            const objStart = text.indexOf('{', serversKeyIndex);
            if (objStart < 0) return null;
            const objEnd = findMatching(text, objStart, '{', '}');
            if (objEnd < 0) return null;

            const keyIndex = text.indexOf(quotedKey, objStart);
            if (keyIndex < 0 || keyIndex > objEnd) return null;

            const colon = text.indexOf(':', keyIndex + quotedKey.length);
            if (colon < 0 || colon > objEnd) return null;

            const valueRange = parseJsonValueRange(text, colon + 1);
            if (!valueRange) return null;

            let start = keyIndex;
            let end = valueRange.end;

            let trailing = end;
            while (trailing < text.length && isWhitespace(text[trailing])) trailing++;
            if (text[trailing] === ',') trailing++;
            end = trailing;

            return { start, end };
          }

          function findTomlMcpServerRange(text, key) {
            const lines = text.split(/\\n/);
            let offset = 0;

            const directHeaders = [
              `[mcp_servers.${key}]`,
              `[mcp_servers.\"${key}\"]`,
              `[mcp_servers.'${key}']`,
            ];

            for (let i = 0; i < lines.length; i++) {
              const line = lines[i];
              const trimmed = line.trim();
              if (directHeaders.includes(trimmed)) {
                const start = offset;
                let endOffset = offset + line.length;
                let j = i + 1;
                let end = endOffset;
                for (; j < lines.length; j++) {
                  const t = lines[j].trim();
                  if (t.startsWith('[') && t.endsWith(']')) break;
                  end += lines[j].length + 1;
                }
                return { start, end: Math.min(end, text.length) };
              }
              offset += line.length + 1;
            }

            // Inline table format under [mcp_servers]
            offset = 0;
            let inServersTable = false;
            let serversStartOffset = -1;
            let serversEndOffset = -1;
            for (let i = 0; i < lines.length; i++) {
              const line = lines[i];
              const trimmed = line.trim();
              if (trimmed === '[mcp_servers]') {
                inServersTable = true;
                serversStartOffset = offset;
              } else if (inServersTable && trimmed.startsWith('[') && trimmed.endsWith(']')) {
                serversEndOffset = offset - 1;
                inServersTable = false;
              }

              if (inServersTable) {
                const candidates = [
                  `${key} =`,
                  `\"${key}\" =`,
                  `'${key}' =`,
                ];
                const match = candidates.find((c) => trimmed.startsWith(c));
                if (match) {
                  const start = offset;
                  const eqIndex = line.indexOf('=');
                  if (eqIndex < 0) return { start, end: offset + line.length };

                  const afterEq = line.slice(eqIndex + 1);
                  const braceIndex = afterEq.indexOf('{');
                  if (braceIndex >= 0) {
                    const absoluteBraceIndex = offset + eqIndex + 1 + braceIndex;
                    const endBrace = findMatching(text, absoluteBraceIndex, '{', '}');
                    if (endBrace >= 0) return { start, end: endBrace + 1 };
                  }

                  return { start, end: offset + line.length };
                }
              }

              offset += line.length + 1;
            }

            return null;
          }

          function computeHighlightRange(text) {
            if (!highlightSpec || !highlightSpec.key || !highlightSpec.format) return null;
            if (highlightSpec.format === 'json') {
              return findJsonMcpServerRange(text, highlightSpec.key);
            }
            if (highlightSpec.format === 'toml') {
              return findTomlMcpServerRange(text, highlightSpec.key);
            }
            return null;
          }

          function computeLineFromIndex(text, index) {
            let line = 0;
            for (let i = 0; i < index; i++) {
              if (text[i] === '\\n') line++;
            }
            return line;
          }

          function updateOverlay() {
            const text = editor.value || '';
            const range = computeHighlightRange(text);

            // Keep overlay scrollable size in sync with the editor content.
            overlayContent.style.height = editor.scrollHeight + 'px';
            overlayContent.style.width = editor.scrollWidth + 'px';

            if (!range || range.start < 0 || range.end <= range.start) {
              highlightBlock.style.display = 'none';
              return;
            }

            const startIndex = Math.max(0, Math.min(range.start, text.length));
            const endIndex = Math.max(0, Math.min(range.end, text.length));
            const startLine = computeLineFromIndex(text, startIndex);
            const endLine = computeLineFromIndex(text, endIndex);

            const style = window.getComputedStyle(editor);
            const lineHeight = parseFloat(style.lineHeight || '18') || 18;
            const paddingTop = parseFloat(style.paddingTop || '14') || 14;
            const paddingLeft = parseFloat(style.paddingLeft || '0') || 0;
            const paddingRight = parseFloat(style.paddingRight || '0') || 0;

            const top = paddingTop + startLine * lineHeight;
            const height = Math.max(lineHeight, (endLine - startLine + 1) * lineHeight);

            highlightBlock.style.display = 'block';
            highlightBlock.style.top = top + 'px';
            highlightBlock.style.height = height + 'px';
            highlightBlock.style.left = paddingLeft + 'px';
            highlightBlock.style.right = paddingRight + 'px';
          }

          function updateGutter() {
            const text = editor.value || '';
            const lines = text.split('\\n');
            const lineCount = Math.max(1, lines.length);
            let out = '';
            for (let i = 1; i <= lineCount; i++) {
              out += i;
              if (i !== lineCount) out += '\\n';
            }
            gutter.textContent = out;
          }

          function scrollToHighlightIfNeeded() {
            const text = editor.value || '';
            const range = computeHighlightRange(text);
            if (!range || range.start < 0) return;

            const start = Math.max(0, Math.min(range.start, text.length));
            const line = computeLineFromIndex(text, start);

            const style = window.getComputedStyle(editor);
            const lineHeight = parseFloat(style.lineHeight || '18') || 18;
            const paddingTop = parseFloat(style.paddingTop || '14') || 14;

            const targetTop = paddingTop + line * lineHeight;
            const viewTop = editor.scrollTop;
            const viewBottom = viewTop + editor.clientHeight;

            // If highlight start isn't visible, center it.
            if (targetTop < viewTop + lineHeight * 2 || targetTop > viewBottom - lineHeight * 2) {
              const centered = Math.max(0, targetTop - editor.clientHeight / 2);
              editor.scrollTop = centered;
              syncScroll();
            }
          }

          function syncScroll() {
            overlay.scrollTop = editor.scrollTop;
            overlay.scrollLeft = editor.scrollLeft;
            gutter.scrollTop = editor.scrollTop;
          }

          editor.addEventListener('input', () => {
            if (!dirty) {
              dirty = true;
              postDirty(true);
            }
            updateGutter();
            updateOverlay();
            syncScroll();
          });

          editor.addEventListener('scroll', syncScroll);

          window.__nolon = {
            setText(text) {
              editor.value = text ?? '';
              dirty = false;
              postDirty(false);
              updateGutter();
              updateOverlay();
              syncScroll();
              scrollToHighlightIfNeeded();
            },
            setHighlight(spec) {
              highlightSpec = spec;
              updateOverlay();
              scrollToHighlightIfNeeded();
            },
            getText() {
              return editor.value ?? '';
            },
          };
        </script>
      </body>
    </html>
    """
}

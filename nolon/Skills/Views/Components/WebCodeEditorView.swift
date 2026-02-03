import SwiftUI
import WebKit

@MainActor
final class WebCodeEditorBridge {
    fileprivate weak var webView: WKWebView?
    fileprivate var isReady = false
    fileprivate var pendingText: String?
    fileprivate var pendingHighlight: WebCodeEditorHighlight?

    func setText(_ text: String) {
        if isReady {
            applyText(text)
        } else {
            pendingText = text
        }
    }

    func setHighlight(_ highlight: WebCodeEditorHighlight?) {
        if isReady {
            applyHighlight(highlight)
        } else {
            pendingHighlight = highlight
        }
    }

    func requestText() async throws -> String {
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

enum WebCodeEditorFormat: String, Sendable {
    case json
    case toml
}

struct WebCodeEditorHighlight: Sendable {
    let format: WebCodeEditorFormat
    let key: String
}

struct WebCodeEditorView: NSViewRepresentable {
    let bridge: WebCodeEditorBridge
    let initialText: String
    let highlight: WebCodeEditorHighlight?
    let onDirtyChanged: (Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
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

    func updateNSView(_ nsView: WKWebView, context: Context) {
        bridge.setHighlight(highlight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge, onDirtyChanged: onDirtyChanged)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let bridge: WebCodeEditorBridge
        private let onDirtyChanged: (Bool) -> Void

        init(bridge: WebCodeEditorBridge, onDirtyChanged: @escaping (Bool) -> Void) {
            self.bridge = bridge
            self.onDirtyChanged = onDirtyChanged
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.markReady()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
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

import SwiftUI
import STJSON
internal import AnyCodable

struct McpEditorView: View {
    let mcp: MCP
    let isToml: Bool
    let onSave: (MCP) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool
    @State private var url: String
    @State private var command: String
    @State private var argsText: String
    @State private var envText: String

    init(mcp: MCP, isToml: Bool, onSave: @escaping (MCP) -> Void) {
        self.mcp = mcp
        self.isToml = isToml
        self.onSave = onSave

        let dict = mcp.dictionaryValue
        _enabled = State(initialValue: mcp.isEnabled)
        _url = State(initialValue: dict["url"] as? String ?? "")
        _command = State(initialValue: dict["command"] as? String ?? "")

        let args = dict["args"] as? [String] ?? []
        _argsText = State(initialValue: args.joined(separator: "\n"))

        let env = dict["env"] as? [String: String] ?? [:]
        let envLines = env.keys.sorted().map { key in "\(key)=\(env[key] ?? "")" }
        _envText = State(initialValue: envLines.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(NSLocalizedString("mcp.field.name", value: "Name", comment: "MCP field name"))
                        Spacer()
                        Text(mcp.name)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Toggle(NSLocalizedString("mcp.field.enabled", value: "Enabled", comment: "MCP enabled"), isOn: $enabled)
                }

                Section(NSLocalizedString("mcp.section.connection", value: "Connection", comment: "MCP connection section")) {
                    TextField(NSLocalizedString("mcp.field.url", value: "URL", comment: "MCP URL"), text: $url)
                        .textSelection(.enabled)
                }

                Section(NSLocalizedString("mcp.section.command", value: "Command", comment: "MCP command section")) {
                    TextField(NSLocalizedString("mcp.field.command", value: "Command", comment: "MCP command"), text: $command)
                        .textSelection(.enabled)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("mcp.field.args", value: "Args (one per line)", comment: "MCP args"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $argsText)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .frame(minHeight: 80)
                    }
                }

                Section(NSLocalizedString("mcp.section.env", value: "Environment", comment: "MCP env section")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("mcp.field.env", value: "Env (KEY=VALUE, one per line)", comment: "MCP env"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $envText)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("mcp.editor.title", value: "Edit MCP", comment: "MCP editor title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("action.save", value: "Save", comment: "Save")) {
                        let updated = buildUpdatedMcp()
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private func buildUpdatedMcp() -> MCP {
        var dict = mcp.dictionaryValue

        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            dict["url"] = nil
        } else {
            dict["url"] = trimmedURL
        }

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCommand.isEmpty {
            dict["command"] = nil
        } else {
            dict["command"] = trimmedCommand
        }

        let args = argsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        dict["args"] = args.isEmpty ? nil : args

        let envLines = envText
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
        var env: [String: String] = [:]
        for line in envLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1])
            guard !key.isEmpty else { continue }
            env[key] = value
        }
        dict["env"] = env.isEmpty ? nil : env

        if isToml {
            dict["enabled"] = enabled
            dict["disabled"] = nil
        } else {
            dict["enabled"] = nil
            dict["disabled"] = enabled ? nil : true
        }

        return mcp.withDictionary(dict)
    }
}


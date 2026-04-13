import Foundation
@preconcurrency import STFilePath
import ProviderCatalog

/// Watches provider-related filesystem locations (skills/workflows/MCP config) and triggers a refresh on change.
@MainActor
public final class ProviderResourceMonitor {
    public typealias OnChange = @MainActor () -> Void

    private let onChange: OnChange
    private var watchers: [STPathWatcher] = []
    private var watchTasks: [Task<Void, Never>] = []
    private var debounceTask: Task<Void, Never>?

    public init(onChange: @escaping OnChange) {
        self.onChange = onChange
    }

    public func startWatching(provider: Provider, watchGlobalMcpCache: Bool = false) {
        stop()

        let targets = watchedTargets(for: provider, watchGlobalMcpCache: watchGlobalMcpCache)
        guard !targets.isEmpty else { return }

        watchers = targets.map { STPathWatcher(path: $0) }
        watchTasks = watchers.map { watcher in
            Task { [weak self] in
                do {
                    for try await _ in watcher.stream() {
                        await self?.scheduleRefresh()
                    }
                } catch {
                    // Ignore watcher errors; a later re-start will recreate watchers.
                }
            }
        }
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        watchTasks.forEach { $0.cancel() }
        watchTasks.removeAll()

        watchers.forEach { $0.stop() }
        watchers.removeAll()
    }

    private func scheduleRefresh() async {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.onChange()
        }
    }

    private func watchedTargets(for provider: Provider, watchGlobalMcpCache: Bool) -> [STPath] {
        var paths: [String] = []
        paths.append(provider.defaultSkillsPath)
        paths.append(provider.workflowPath)
        paths.append(contentsOf: provider.additionalSkillsPaths ?? [])

        if let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
            paths.append(template.defaultMcpConfigPath.path)
        }

        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            paths.append(provider.codexAgentsFileURL.path)
            paths.append(provider.codexAgentsOverrideFile.url.path)
            if provider.agentsLinkEnabled {
                paths.append(NolonManager.shared.agentsURL.path)
            }
        } else if provider.templateId == ProviderTemplate.claudeCode.rawValue {
            paths.append(provider.claudeInstructionsFileURL.path)
            if provider.agentsLinkEnabled {
                paths.append(NolonManager.shared.agentsURL.path)
            }
        } else if provider.templateId == "opencode" {
            let opencodeHome = URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent()
            paths.append(opencodeHome.appendingPathComponent("AGENTS.md").path)
        } else if provider.templateId == "copilot" {
            let copilotHome = URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent()
            paths.append(copilotHome.appendingPathComponent("AGENTS.md").path)
            let env = ProcessInfo.processInfo.environment["COPILOT_CUSTOM_INSTRUCTIONS_DIRS"] ?? ""
            let directories = env
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for directory in directories {
                let expanded = (directory as NSString).expandingTildeInPath
                paths.append(URL(fileURLWithPath: expanded).appendingPathComponent("AGENTS.md").path)
            }
        }

        if provider.mcpLinkEnabled || watchGlobalMcpCache {
            paths.append(NolonManager.shared.mcpsURL.path)
        }

        // Canonicalize + dedupe.
        var unique: [String] = []
        var seen = Set<String>()
        for raw in paths {
            let normalized = STPath(raw).url.standardizedFileURL.path
            guard seen.insert(normalized).inserted else { continue }
            unique.append(normalized)
        }

        // Prefer watching the target if it exists; otherwise watch its parent directory so we can
        // still pick up creation of the target later.
        var targets: [STPath] = []
        var seenTargets = Set<String>()
        for path in unique {
            let st = STPath(path)
            let target: STPath
            if st.isExists || st.isSymbolicLink {
                target = st
            } else {
                target = STPath((path as NSString).deletingLastPathComponent)
            }
            let key = target.url.standardizedFileURL.path
            guard !key.isEmpty, seenTargets.insert(key).inserted else { continue }
            targets.append(target)
        }

        return targets
    }
}

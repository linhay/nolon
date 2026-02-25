import Foundation
import ProviderCatalog
import STFilePath

public final class ProviderDiscoveryService: @unchecked Sendable {
    public typealias PathExists = @Sendable (String) -> Bool
    public typealias CLIResolver = @Sendable (String) -> String?

    private let pathExists: PathExists
    private let cliResolver: CLIResolver

    public init(
        pathExists: @escaping PathExists = { path in STPath(path).isExists },
        cliResolver: @escaping CLIResolver = { executable in
            let candidates = [
                "/opt/homebrew/bin/\(executable)",
                "/usr/local/bin/\(executable)",
                "/usr/bin/\(executable)",
            ]
            for path in candidates {
                let candidate = STPath(path)
                if candidate.isExists, candidate.permission.contains(.executable) {
                    return candidate.url.standardizedFileURL.path
                }
            }
            return nil
        }
    ) {
        self.pathExists = pathExists
        self.cliResolver = cliResolver
    }

    public func detectInstalledProviders(templates: [ProviderTemplate] = ProviderTemplate.allCases) -> Set<ProviderTemplate> {
        var detected: Set<ProviderTemplate> = []
        for template in templates {
            let skillsPath = template.defaultSkillsPath.path
            let workflowPath = template.defaultWorkflowPath.path
            let commandPath = template.defaultCommandPath?.path
            if pathExists(skillsPath) || pathExists(workflowPath) || (commandPath.map(pathExists) ?? false) {
                detected.insert(template)
            }
        }
        return detected
    }

    public func templatesWithInstalledCLI(templates: [ProviderTemplate] = ProviderTemplate.allCases) -> [ProviderTemplate] {
        var found: [ProviderTemplate] = []
        var seen = Set<String>()
        for template in templates {
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { continue }
            guard cliResolver(executable) != nil else { continue }
            let key = template.providerID.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            found.append(template)
        }
        return found.sorted {
            $0.providerID.localizedCaseInsensitiveCompare($1.providerID) == .orderedAscending
        }
    }
}

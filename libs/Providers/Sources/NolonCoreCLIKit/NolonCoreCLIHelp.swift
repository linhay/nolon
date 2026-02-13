import Foundation

enum NolonCoreCLIHelpResolver {
    static func resolvedHelpText(arguments: [String]) -> String? {
        let normalized = arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let key = NolonCoreCLIHelpPath(arguments: normalized) else { return nil }
        switch key {
        case .skills:
            return skillsHelpText()
        case .skillsRepo:
            return skillsRepoHelpText()
        case .resources:
            return resourcesHelpText()
        case .remote:
            return remoteHelpText()
        }
    }

    private static func skillsHelpText() -> String {
        """
        Usage: nolon skills <subcommand> [options]

        Subcommands:
          repo      plan | preflight | sync
          discover  --path <path> [--max-depth <n>]
          parse     --file <path> [--directory-name <name>]
          install   --skill-path <path> --provider-path <path> [--skill-id <id>] [--install-method symlink|copy]
          uninstall --skill-id <id> --provider-path <path>
          migrate   scan | apply
        """
    }

    private static func skillsRepoHelpText() -> String {
        """
        Usage: nolon skills repo <action> [options]

        Actions:
          plan       --source <git/ref> --repositories-root <path>
          preflight  --source <git/ref> [--pull-strategy ff-only|rebase|merge] [--credential-strategy automatic|prefer-ssh|token-only|ssh-only]
          sync       --source <git/ref> --repositories-root <path> [--access-token <token>]
        """
    }

    private static func resourcesHelpText() -> String {
        """
        Usage: nolon resources <action> [options]

        Actions:
          discover   --path <repo-path> [--max-depth <n>]
          install    --kind workflow|mcp --file-path <path> --target-path <path> [--resource-name <name>] [--install-method symlink|copy]
          uninstall  --kind workflow|mcp --resource-name <name> --target-path <path>
        """
    }

    private static func remoteHelpText() -> String {
        """
        Usage: nolon remote <action> [options]

        Actions:
          list      --kind skill|workflow|mcp [--query <text>] [--limit <n>] [--base-url <url>]
          download  --kind skill|workflow|mcp --slug <slug> [--version <ver>] [--base-url <url>]
          sync      --source <git/ref> --repositories-root <path> [--access-token <token>] [--pull-strategy ff-only|rebase|merge] [--credential-strategy automatic|prefer-ssh|token-only|ssh-only] [--max-depth <n>]
          sync-install --kind skill|workflow|mcp --source <git/ref> --repositories-root <path> (--path <repo-relative-or-absolute-path> | --slug <resource-slug>) [--strict-selector true|false]
                    skill:   (--provider-path <path> | --provider-id <id>) [--skill-id <id>] [--install-method symlink|copy]
                    workflow/mcp: (--target-path <path> | --provider-id <id>) [--resource-name <name>] [--install-method symlink|copy]
          install   --kind skill|workflow|mcp --slug <slug> [--version <ver>] [--base-url <url>]
                    skill:   (--provider-path <path> | --provider-id <id>) [--skill-id <id>] [--install-method symlink|copy]
                    workflow/mcp: (--target-path <path> | --provider-id <id>) [--resource-name <name>] [--install-method symlink|copy]
        """
    }
}

private enum NolonCoreCLIHelpPath {
    case skills
    case skillsRepo
    case resources
    case remote

    init?(arguments: [String]) {
        switch arguments {
        case ["skills"], ["skills", "help"], ["skills", "-h"], ["skills", "--help"]:
            self = .skills
        case ["skills", "repo"], ["skills", "repo", "help"], ["skills", "repo", "-h"], ["skills", "repo", "--help"]:
            self = .skillsRepo
        case ["resources"], ["resources", "help"], ["resources", "-h"], ["resources", "--help"]:
            self = .resources
        case ["remote"], ["remote", "help"], ["remote", "-h"], ["remote", "--help"]:
            self = .remote
        default:
            return nil
        }
    }
}

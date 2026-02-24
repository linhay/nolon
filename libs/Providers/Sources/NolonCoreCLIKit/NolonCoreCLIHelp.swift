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
        case .workflow:
            return workflowHelpText()
        case .mcp:
            return mcpHelpText()
        case .remote:
            return remoteHelpText()
        }
    }

    private static func skillsHelpText() -> String {
        """
        Usage: nolon skills <subcommand> [options]

        Subcommands:
          list      [--provider <id>|--provider-id <id>] [--state installed|orphaned|broken] [--include-empty] [--verbose] [--show-fixes]
          sync      --source <git/ref> [--repositories-root <path>] [--access-token <token>]
          search    [<keyword> | --query <query>] [--limit <n>] [--base-url <url>] [--install [--provider <id>|--provider-id <id>] [--install-method symlink|copy] [--pick <index>] [--dry-run|--yes]]
          add       <slug> [--provider <id>|--provider-id <id>] [--version <ver>] [--install-method symlink|copy] [--dry-run]
                    默认先从本地 repositories-root 查找；未命中则回退远程 base-url。
                    所有来源统一先缓存到 NOLON_HOME/skills/<slug>，再分发到目标 provider。
                    省略 --provider 时，默认分发到已安装 CLI 的全部 provider。
                    注意：省略 --provider 可能触发多 provider 批量写入/覆盖；建议先使用 --dry-run 预览范围。
          remove    --skill-id <id> (--provider-path <path> | --provider <id> | --provider-id <id>)

        场景: 发现技能
          nolon skills search xcode

        场景: 安装技能
          nolon skills add xcode --provider codex

        场景: 修复异常
          nolon skills list --provider codex --state broken
        """
    }

    private static func skillsRepoHelpText() -> String {
        """
        Usage: nolon skills repo <action> [options]

        Actions:
          list       [--repositories-root <path>] [--max-depth <n>] [--verbose]
          plan       --source <git/ref> --repositories-root <path>
          preflight  --source <git/ref> [--pull-strategy ff-only|rebase|merge] [--credential-strategy automatic|prefer-ssh|token-only|ssh-only]
          sync       --source <git/ref> [--repositories-root <path>] [--access-token <token>]
        """
    }

    private static func workflowHelpText() -> String {
        """
        Usage: nolon workflow <subcommand> [options]

        Subcommands:
          list      [--provider <id>|--provider-id <id>] [--state installed|orphaned|broken] [--include-empty] [--verbose] [--show-fixes]
          sync      --source <git/ref> [--repositories-root <path>] [--access-token <token>]
          search    [<keyword> | --query <query>] [--limit <n>] [--base-url <url>] [--install [--provider <id>|--provider-id <id>] [--install-method symlink|copy] [--pick <index>] [--dry-run|--yes]]
          add       <slug> [--provider <id>|--provider-id <id>] [--version <ver>] [--install-method symlink|copy] [--dry-run]
          remove    --resource-name <name> (--target-path <path> | --provider <id> | --provider-id <id>)

        场景: 搜索工作流
          nolon workflow search xcode

        场景: 安装工作流
          nolon workflow add xcode --provider codex --dry-run

        场景: 修复异常
          nolon workflow list --provider codex --state broken
        """
    }

    private static func mcpHelpText() -> String {
        """
        Usage: nolon mcp <subcommand> [options]

        Subcommands:
          list      [--provider <id>|--provider-id <id>] [--state installed|orphaned|broken] [--include-empty] [--verbose] [--show-fixes]
          sync      --source <git/ref> [--repositories-root <path>] [--access-token <token>]
          search    [<keyword> | --query <query>] [--limit <n>] [--base-url <url>] [--install [--provider <id>|--provider-id <id>] [--install-method symlink|copy] [--pick <index>] [--dry-run|--yes]]
          add       <slug> [--provider <id>|--provider-id <id>] [--version <ver>] [--install-method symlink|copy] [--dry-run]
          remove    --resource-name <name> (--target-path <path> | --provider <id> | --provider-id <id>)

        场景: 搜索 MCP
          nolon mcp search xcode

        场景: 安装 MCP
          nolon mcp add playwright --provider codex --dry-run

        场景: 修复异常
          nolon mcp list --provider codex --state broken
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
    case workflow
    case mcp
    case remote

    init?(arguments: [String]) {
        switch arguments {
        case ["skills"], ["skills", "help"], ["skills", "-h"], ["skills", "--help"]:
            self = .skills
        case ["skills", "repo"], ["skills", "repo", "help"], ["skills", "repo", "-h"], ["skills", "repo", "--help"]:
            self = .skillsRepo
        case ["workflow"], ["workflow", "help"], ["workflow", "-h"], ["workflow", "--help"]:
            self = .workflow
        case ["mcp"], ["mcp", "help"], ["mcp", "-h"], ["mcp", "--help"]:
            self = .mcp
        case ["remote"], ["remote", "help"], ["remote", "-h"], ["remote", "--help"]:
            self = .remote
        default:
            return nil
        }
    }
}

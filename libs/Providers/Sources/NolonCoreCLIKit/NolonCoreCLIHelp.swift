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
          list
            --provider <id>|--provider-id <id>           # 按 provider 过滤
            --state installed|orphaned|broken            # 按状态过滤
            --include-empty                              # 包含空 provider
            --verbose                                    # 显示完整路径与来源
            --show-fixes                                 # 输出修复建议
          sync
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（可选）
            --access-token <token>                       # 私仓访问令牌（可选）
          search
            <keyword> | --query <query>                  # 关键词（两种写法二选一）
            --limit <n>                                  # 返回条数上限
            --base-url <url>                             # 远端 API 地址
            --install                                    # 直接安装匹配项
            --provider <id>|--provider-id <id>           # 与 --install 一起使用，指定 provider
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run|--yes                              # 与 --install 一起使用，预览或确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>|--provider-id <id>           # 目标 provider（可选）
            --version <ver>                              # 指定版本（可选）
            --install-method symlink|copy                # 安装方式（可选）
            --dry-run                                    # 仅预览，不落盘
            默认先从本地 repositories-root 查找；未命中则回退远程 base-url。
            所有来源统一先缓存到 NOLON_HOME/skills/<slug>，再分发到目标 provider。
            省略 --provider 时，默认分发到已安装 CLI 的全部 provider。
            注意：省略 --provider 可能触发多 provider 批量写入/覆盖；建议先使用 --dry-run 预览范围。
          remove
            --skill-id <id>                              # 技能 ID（必填）
            --provider-path <path>                       # 直接指定 provider 目录（三选一）
            --provider <id>                              # 指定 provider（三选一）
            --provider-id <id>                           # provider 别名参数（三选一）

        场景: 搜索技能
          nolon skills search xcode

        场景: 安装技能
          nolon skills add xcode --provider codex --dry-run

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
          list
            --provider <id>|--provider-id <id>           # 按 provider 过滤
            --state installed|orphaned|broken            # 按状态过滤
            --include-empty                              # 包含空 provider
            --verbose                                    # 显示完整路径与来源
            --show-fixes                                 # 输出修复建议
          sync
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（可选）
            --access-token <token>                       # 私仓访问令牌（可选）
          search
            <keyword> | --query <query>                  # 关键词（两种写法二选一）
            --limit <n>                                  # 返回条数上限
            --base-url <url>                             # 远端 API 地址
            --install                                    # 直接安装匹配项
            --provider <id>|--provider-id <id>           # 与 --install 一起使用，指定 provider
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run|--yes                              # 与 --install 一起使用，预览或确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>|--provider-id <id>           # 目标 provider（可选）
            --version <ver>                              # 指定版本（可选）
            --install-method symlink|copy                # 安装方式（可选）
            --dry-run                                    # 仅预览，不落盘
          remove
            --resource-name <name>                       # 资源名（必填）
            --target-path <path>                         # 直接指定目录（三选一）
            --provider <id>                              # 指定 provider（三选一）
            --provider-id <id>                           # provider 别名参数（三选一）

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
          list
            --provider <id>|--provider-id <id>           # 按 provider 过滤
            --state installed|orphaned|broken            # 按状态过滤
            --include-empty                              # 包含空 provider
            --verbose                                    # 显示完整路径与来源
            --show-fixes                                 # 输出修复建议
          sync
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（可选）
            --access-token <token>                       # 私仓访问令牌（可选）
          search
            <keyword> | --query <query>                  # 关键词（两种写法二选一）
            --limit <n>                                  # 返回条数上限
            --base-url <url>                             # 远端 API 地址
            --install                                    # 直接安装匹配项
            --provider <id>|--provider-id <id>           # 与 --install 一起使用，指定 provider
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run|--yes                              # 与 --install 一起使用，预览或确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>|--provider-id <id>           # 目标 provider（可选）
            --version <ver>                              # 指定版本（可选）
            --install-method symlink|copy                # 安装方式（可选）
            --dry-run                                    # 仅预览，不落盘
          remove
            --resource-name <name>                       # 资源名（必填）
            --target-path <path>                         # 直接指定目录（三选一）
            --provider <id>                              # 指定 provider（三选一）
            --provider-id <id>                           # provider 别名参数（三选一）

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

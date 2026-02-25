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
            --provider <id>                              # 按 provider 过滤
            --provider-id <id>                           # provider 别名参数
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
            --provider <id>                              # 与 --install 一起使用，指定 provider
            --provider-id <id>                           # provider 别名参数
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run                                    # 与 --install 一起使用，预览执行
            --yes                                        # 与 --install 一起使用，确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>                              # 目标 provider（可选）
            --provider-id <id>                           # provider 别名参数
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
          list
            --repositories-root <path>                   # 本地仓库根目录（可选）
            --max-depth <n>                              # 扫描深度（可选）
            --verbose                                    # 展示完整路径与统计明细
          plan
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（必填）
          preflight
            --source <git/ref>                           # 远程仓库来源（必填）
            --pull-strategy ff-only|rebase|merge         # 拉取策略（可选）
            --credential-strategy automatic|prefer-ssh|token-only|ssh-only  # 凭据策略（可选）
          sync
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（可选）
            --access-token <token>                       # 私仓访问令牌（可选）
        """
    }

    private static func workflowHelpText() -> String {
        """
        Usage: nolon workflow <subcommand> [options]

        Subcommands:
          list
            --provider <id>                              # 按 provider 过滤
            --provider-id <id>                           # provider 别名参数
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
            --provider <id>                              # 与 --install 一起使用，指定 provider
            --provider-id <id>                           # provider 别名参数
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run                                    # 与 --install 一起使用，预览执行
            --yes                                        # 与 --install 一起使用，确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>                              # 目标 provider（可选）
            --provider-id <id>                           # provider 别名参数
            --version <ver>                              # 指定版本（可选）
            --install-method symlink|copy                # 安装方式（可选）
            --dry-run                                    # 仅预览，不落盘
            默认先从本地 repositories-root 查找；未命中则回退远程 base-url。
            所有来源统一先缓存到 NOLON_HOME/workflows/<slug>，再分发到目标 provider。
            省略 --provider 时，默认分发到已安装 CLI 的全部 provider。
            注意：省略 --provider 可能触发多 provider 批量写入/覆盖；建议先使用 --dry-run 预览范围。
          remove
            --resource-name <name>                       # 资源名（必填）
            --target-path <path>                         # 直接指定目录（三选一）
            --provider <id>                              # 指定 provider（三选一）
            --provider-id <id>                           # provider 别名参数（三选一）
          bind-skill
            --skill-id <id>                              # 技能 ID（必填）
            --target-path <path>                         # 直接指定目录（二选一）
            --provider <id>                              # 指定 provider（二选一）
            --provider-id <id>                           # provider 别名参数（二选一）
          bind-mcp
            --mcp-name <name>                            # MCP 名称（必填）
            --target-path <path>                         # 直接指定目录（二选一）
            --provider <id>                              # 指定 provider（二选一）
            --provider-id <id>                           # provider 别名参数（二选一）
          unbind-skill
            --skill-id <id>                              # 技能 ID（必填）
            --target-path <path>                         # 直接指定目录（二选一）
            --provider <id>                              # 指定 provider（二选一）
            --provider-id <id>                           # provider 别名参数（二选一）
          unbind-mcp
            --mcp-name <name>                            # MCP 名称（必填）
            --target-path <path>                         # 直接指定目录（二选一）
            --provider <id>                              # 指定 provider（二选一）
            --provider-id <id>                           # provider 别名参数（二选一）

        场景: 搜索工作流
          nolon workflow search xcode

        场景: 安装工作流
          nolon workflow add xcode --provider codex --dry-run

        场景: 从 skill 绑定 workflow
          nolon workflow bind-skill --skill-id find-skills --provider codex

        场景: 从 mcp 解绑 workflow
          nolon workflow unbind-mcp --mcp-name playwright --provider codex

        场景: 修复异常
          nolon workflow list --provider codex --state broken
        """
    }

    private static func mcpHelpText() -> String {
        """
        Usage: nolon mcp <subcommand> [options]

        Subcommands:
          list
            --provider <id>                              # 按 provider 过滤
            --provider-id <id>                           # provider 别名参数
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
            --provider <id>                              # 与 --install 一起使用，指定 provider
            --provider-id <id>                           # provider 别名参数
            --install-method symlink|copy                # 与 --install 一起使用，指定安装方式
            --pick <index>                               # 与 --install 一起使用，选中候选序号
            --dry-run                                    # 与 --install 一起使用，预览执行
            --yes                                        # 与 --install 一起使用，确认执行
          add
            <slug>                                       # 资源标识（必填）
            --provider <id>                              # 目标 provider（可选）
            --provider-id <id>                           # provider 别名参数
            --version <ver>                              # 指定版本（可选）
            --install-method symlink|copy                # 安装方式（可选）
            --dry-run                                    # 仅预览，不落盘
            默认先从本地 repositories-root 查找；未命中则回退远程 base-url。
            所有来源统一先缓存到 NOLON_HOME/mcps/<slug>，再分发到目标 provider。
            省略 --provider 时，默认分发到已安装 CLI 的全部 provider。
            注意：省略 --provider 可能触发多 provider 批量写入/覆盖；建议先使用 --dry-run 预览范围。
          remove
            --resource-name <name>                       # 资源名（必填）
            --target-path <path>                         # 直接指定目录（三选一）
            --provider <id>                              # 指定 provider（三选一）
            --provider-id <id>                           # provider 别名参数（三选一）
          server list
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
          server set-enabled
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
            --name <name>                                # 服务器名称（必填）
            --enabled                                    # 启用（与 --disabled 二选一）
            --disabled                                   # 禁用（与 --enabled 二选一）
          server upsert
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
            --name <name>                                # 服务器名称（必填）
            --url <url>                                  # 远程地址（可选）
            --command <command>                          # 本地命令（可选）
            --arg <value>                                # 命令参数（可重复）
            --env KEY=VALUE                              # 环境变量（可重复）
            --enabled                                    # 显式启用（可选）
            --disabled                                   # 显式禁用（可选）
          server remove
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
            --name <name>                                # 服务器名称（必填）
          cache migrate
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
            --overwrite                                  # 覆盖已存在缓存（可选）
          cache status
            --provider <id>                              # provider（必填）
            --provider-id <id>                           # provider 别名参数（必填）
            --name <name>                                # 仅查询指定服务器（可选）

        场景: 搜索 MCP
          nolon mcp search xcode

        场景: 安装 MCP
          nolon mcp add playwright --provider codex --dry-run

        场景: 管理 MCP servers
          nolon mcp server list --provider codex
          nolon mcp server set-enabled --provider codex --name playwright --disabled

        场景: 迁移 MCP cache
          nolon mcp cache migrate --provider codex --overwrite
          nolon mcp cache status --provider codex --name playwright

        场景: 修复异常
          nolon mcp list --provider codex --state broken
        """
    }

    private static func remoteHelpText() -> String {
        """
        Usage: nolon remote <action> [options]

        Actions:
          list
            --kind skill|workflow|mcp                    # 资源类型（必填）
            --query <text>                               # 搜索关键词（可选）
            --limit <n>                                  # 返回条数上限（可选）
            --base-url <url>                             # 远端 API 地址（可选）
          download
            --kind skill|workflow|mcp                    # 资源类型（必填）
            --slug <slug>                                # 资源标识（必填）
            --version <ver>                              # 指定版本（可选）
            --base-url <url>                             # 远端 API 地址（可选）
          sync
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（必填）
            --access-token <token>                       # 私仓访问令牌（可选）
            --pull-strategy ff-only|rebase|merge         # 拉取策略（可选）
            --credential-strategy automatic|prefer-ssh|token-only|ssh-only  # 凭据策略（可选）
            --max-depth <n>                              # 扫描深度（可选）
          sync-install
            --kind skill|workflow|mcp                    # 资源类型（必填）
            --source <git/ref>                           # 远程仓库来源（必填）
            --repositories-root <path>                   # 本地仓库根目录（必填）
            --path <repo-relative-or-absolute-path>      # 本地文件路径（二选一）
            --slug <resource-slug>                       # 资源 slug（二选一）
            --strict-selector true|false                 # 是否启用严格匹配（可选）
            skill 目标:
              --provider-path <path> | --provider-id <id>  # 安装目标（二选一）
              --skill-id <id>                              # 覆盖安装名（可选）
              --install-method symlink|copy                # 安装方式（可选）
            workflow/mcp 目标:
              --target-path <path> | --provider-id <id>    # 安装目标（二选一）
              --resource-name <name>                       # 覆盖资源名（可选）
              --install-method symlink|copy                # 安装方式（可选）
          install
            --kind skill|workflow|mcp                    # 资源类型（必填）
            --slug <slug>                                # 资源标识（必填）
            --version <ver>                              # 指定版本（可选）
            --base-url <url>                             # 远端 API 地址（可选）
            skill 目标:
              --provider-path <path> | --provider-id <id>  # 安装目标（二选一）
              --skill-id <id>                              # 覆盖安装名（可选）
              --install-method symlink|copy                # 安装方式（可选）
            workflow/mcp 目标:
              --target-path <path> | --provider-id <id>    # 安装目标（二选一）
              --resource-name <name>                       # 覆盖资源名（可选）
              --install-method symlink|copy                # 安装方式（可选）
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

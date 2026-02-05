# Skill: preferences

用于沉淀“稳定的个人/团队偏好”，减少重复澄清与返工。

## scope
- 本仓库（Nolon）
- 输出语言：优先中文（除非用户明确要求英文）

## do
- **先确认约束**：涉及“只允许改某个目录/文件范围”的要求时，严格限制改动范围，并在收尾明确列出触碰的文件路径。
- **有官方链接先对齐官方**：用户给出“在线文档/标准格式/链接”时，先按链接内容对齐（尤其是配置文件路径与 JSON 结构），不要凭记忆推断。
- **UI 文案必须本地化**：新增/修改 UI 文案必须走 `Localizable.xcstrings`，避免硬编码字符串。
- **遵循 DesignSystem 颜色**：UI 颜色必须使用 `DesignSystem.Colors`（避免 `Color.blue`/`Color.white`/`Color.label` 等硬编码）。
- **用量倒计时格式（Nolon Usage UI）**：周期与倒计时使用紧凑单位，英文 `w/d/h/m`，中文 `周/天/小时/分钟`；避免显示“Window/周期”等标签；布局上周期靠左、倒计时靠右。
- **文件路径类型**：使用 `STFolder` / `STFile`（必要时 `STPathProtocol`），避免仅为取路径而定义 `URL` 变量。
- **行为可验证**：每次修改后提供可执行的验证方式（例如 `./build.sh`）。
- **外部 CLI 的 env/PATH 一致性**：App/测试里调用外部 CLI（如 `codex`）时，优先在统一的进程执行层（如 `SKProcessRunner`）合并 login shell env（尤其 PATH），避免“终端能跑但 App/test 找不到”的差异。
- **CLI 缺失只给诊断指引**：当用户反馈命令找不到时，优先解释原因（未安装/PATH）并给出检查步骤，避免直接执行安装。
- **Live tests 必须可控**：读取用户 env/配置的 live tests 必须由环境变量开关启用，并在缺少必需 env 时可跳过（skip），避免默认跑 CI/本地失败。
- **中断重入先验状态**：出现 `<turn_aborted>` 或用户多次中断后继续时，先验证当前 repo 状态再继续（避免基于过期假设重复操作）。
- **MCP 迁移默认逐个**：MCP 迁移/同步到 `~/.nolon/mcps` 默认按单个 MCP 进行；UI 上已迁移则不显示“迁移”，若配置不一致显示“更新”。

## dont
- 不要在用户未授权时运行可能需要额外权限/写入用户缓存的命令；如果构建失败与缓存权限相关，先说明原因再请求允许。
- 不要在用户机器上自动安装/升级第三方 CLI 或依赖（如 `codex`、`npm`）；除非用户明确要求。
- 不要把无 YAML frontmatter 的 Markdown 当作 workflow。
- 不要捏造引用/链接来源；不能访问或未实际打开官方链接时，不要用“引用”形式伪装已验证。

## examples
- 需要新增按钮文案时：先加 `NSLocalizedString("key", comment: "...")`，再补齐 `Localizable.xcstrings` 对应语言。
- 用户要求“只改 .agent/*”时：仅提交 `.agent/skills/*`、`.agent/workflows/*`、`.agent/CHANGELOG/*` 下变更。
- 用户给出 OpenCode/Claude MCP 文档链接时：先确认“配置文件路径 + key（如 `mcp` vs `mcpServers`）+ server schema（type/headers/env）”，再修改模板/解析逻辑。
- 用户反馈 “command not found” 时：只给诊断步骤与手动安装指引，避免执行安装或自动修复。

## exceptions
- 用户明确允许/要求硬编码或跳过本地化时，才可例外，并在 CHANGELOG 记录原因。

## validation
- `git status` 中的变更路径必须全部落在用户指定的范围内（如 `.agent/`）。
- `./build.sh` 通过（若用户要求构建验证）。

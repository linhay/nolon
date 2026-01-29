# Skill: preferences

用于沉淀“稳定的个人/团队偏好”，减少重复澄清与返工。

## scope
- 本仓库（Nolon）
- 输出语言：优先中文（除非用户明确要求英文）

## do
- **先确认约束**：涉及“只允许改某个目录/文件范围”的要求时，严格限制改动范围，并在收尾明确列出触碰的文件路径。
- **UI 文案必须本地化**：新增/修改 UI 文案必须走 `Localizable.xcstrings`，避免硬编码字符串。
- **遵循 DesignSystem 颜色**：UI 颜色必须使用 `DesignSystem.Colors`（避免 `Color.blue`/`Color.white`/`Color.label` 等硬编码）。
- **行为可验证**：每次修改后提供可执行的验证方式（例如 `./build.sh`）。

## dont
- 不要在用户未授权时运行可能需要额外权限/写入用户缓存的命令；如果构建失败与缓存权限相关，先说明原因再请求允许。
- 不要把无 YAML frontmatter 的 Markdown 当作 workflow。

## examples
- 需要新增按钮文案时：先加 `NSLocalizedString("key", comment: "...")`，再补齐 `Localizable.xcstrings` 对应语言。
- 用户要求“只改 .agent/*”时：仅提交 `.agent/skills/*`、`.agent/workflows/*`、`.agent/CHANGELOG/*` 下变更。

## exceptions
- 用户明确允许/要求硬编码或跳过本地化时，才可例外，并在 CHANGELOG 记录原因。

## validation
- `git status` 中的变更路径必须全部落在用户指定的范围内（如 `.agent/`）。
- `./build.sh` 通过（若用户要求构建验证）。

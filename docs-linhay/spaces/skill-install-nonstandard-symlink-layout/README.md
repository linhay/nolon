# 非标 Skill 目录符号链接兼容（2026-03-03）

## 背景
- 部分仓库（如 `nextlevelbuilder/ui-ux-pro-max-skill`）将 `SKILL.md` 放在 `.claude/skills/<slug>/`，并通过相对符号链接引用 `src/<slug>/scripts`、`data`。
- Nolon 安装时会把 skill 子目录复制到 `~/.nolon/skills/<slug>`，复制后相对链接脱离原仓库上下文而失效。

## 目标
- 安装本地 skill 时，保证落地到 `~/.nolon/skills/<slug>` 的目录自包含可用。
- 对标准仓库保持兼容，不改变已有行为。

## 规则
1. 复制 skill 目录后，扫描源目录中的符号链接条目。
2. 对可解析且目标存在的符号链接：在目标目录中删除对应链接并复制实际文件/目录。
3. 对不可解析或目标不存在的符号链接：保持现状，不阻塞安装。
4. 当 provider 的 `skills` 根目录本身已经链接到 `~/.nolon/skills` 时，从仓库安装 skill 必须直接复制到 `~/.nolon/skills/<slug>`，禁止在全局 skills 根目录内再生成 skill 级符号链接。
5. 当 provider `skills` 根目录的父目录或上游目录通过符号链接最终解析到 `~/.nolon/skills` 时，也必须视为 linked-root 变体，仍然直接物化复制到最终全局目录。
6. 安装失败时，Resource Center 必须立即结束“安装中”状态并展示真实错误；timeout 仅作为兜底，不得覆盖同步可得的安装错误。

## BDD 验收
1. Given skill 目录含 `scripts -> ../../../src/<slug>/scripts` 相对链接，When 执行本地安装，Then `~/.nolon/skills/<slug>/scripts` 为实体目录且脚本文件可读。
2. Given 标准自包含 skill 目录，When 执行本地安装，Then 安装行为与之前一致。
3. Given 链接目标不存在，When 安装，Then 不因该链接直接失败（按原错误链路继续处理 SKILL.md）。
4. Given `codex/skills` 已整体链接到 `~/.nolon/skills`，When 从本地仓库安装 `scale`，Then `~/.nolon/skills/scale` 为实体目录，且不是指回仓库源目录的符号链接。
5. Given provider `skills` 的父目录经过符号链接解析后落到 `~/.nolon/skills`，When 从本地仓库安装 `scale`，Then `~/.nolon/skills/scale` 仍为实体目录，且不会被错误替换成 skill 级符号链接。
6. Given Resource Center 安装链路抛出明确错误，When 用户点击安装，Then 卡片或详情页应立即移除 pending 状态并显示真实错误，而不是等待 45 秒 timeout 后再提示 retry。

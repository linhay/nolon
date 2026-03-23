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

## BDD 验收
1. Given skill 目录含 `scripts -> ../../../src/<slug>/scripts` 相对链接，When 执行本地安装，Then `~/.nolon/skills/<slug>/scripts` 为实体目录且脚本文件可读。
2. Given 标准自包含 skill 目录，When 执行本地安装，Then 安装行为与之前一致。
3. Given 链接目标不存在，When 安装，Then 不因该链接直接失败（按原错误链路继续处理 SKILL.md）。

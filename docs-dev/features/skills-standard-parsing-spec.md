# Skills 标准解析规格（agentskills.io）

- 状态：Draft
- 更新时间：2026-02-12
- 关联：`docs-dev/dev/codex-runtime-refactor.md`
- 参考规范：<https://agentskills.io/specification>

## 背景
当前 `SkillParser` 只做基础 frontmatter 读取（`name/description/version`），缺少对 skills 规范字段的结构化解析与校验，不利于后续跨仓库兼容与质量控制。

## 目标
1. 支持按标准解析 `SKILL.md` frontmatter 的核心字段。
2. 产出结构化元数据（不仅是扁平字符串字典）。
3. 提供“可兼容”的规范校验告警（warning），默认不阻断旧技能。

## 标准字段（本阶段落地）
1. `name`：标准技能名（建议 kebab-case，最长 64）。
2. `description`：技能描述（建议最长 1024）。
3. `license`：可选。
4. `compatibility`：可选（建议最长 500）。
5. `metadata`：可选对象（`[String: String]`）。
6. `argument-hint`：可选（可在顶层或 `metadata` 中读取）。
7. `allowed-tools`：可选（按空白分隔为字符串数组）。

## 规范校验增强（2026-02-12 第三轮）
1. 引入结构化 `issues`（`code` + `severity` + `message`）并保留 `warnings` 兼容字段。
2. `name` / `description` 缺失或空值按 `error` 级别输出（`missing_name` / `missing_description`）。
3. `isValid` 由 `issues` 自动推导（存在 `error` 即 `false`）。
4. `allowed-tools` 输入兼容：
   - 空白分隔字符串
   - 逗号分隔字符串
   - YAML 数组（含混合类型，非字符串项转字符串并告警）

## 非目标
1. 本阶段不改 UI 展示。
2. 本阶段不强制阻断不合规 skills（仅告警）。
3. 不修改已有 `Skill` 领域模型字段结构。

## BDD 场景

### 场景 1：标准 frontmatter 解析
- Given: `SKILL.md` 包含 `name`、`description`、`license`、`metadata`
- When: 调用标准解析入口
- Then: 返回结构化元数据（name/description/license/metadata）
- And: `warnings` 为空

### 场景 2：目录名与 name 不一致
- Given: 目录名为 `agent-browser`，frontmatter `name: browser-agent`
- When: 调用标准解析入口
- Then: 解析成功
- And: `warnings` 包含 name 与目录不匹配告警

### 场景 3：非规范 name 格式
- Given: `name` 包含不推荐字符（如空格或大写）
- When: 调用标准解析入口
- Then: 解析成功
- And: `warnings` 包含 name 格式告警

### 场景 4：兼容旧技能（无 frontmatter）
- Given: `SKILL.md` 无 frontmatter
- When: 调用既有 `SkillParser.parse`
- Then: 仍回退到旧默认行为（name=id, description 默认值）

### 场景 5：compatibility 与 allowed-tools 解析
- Given: `SKILL.md` 包含 `compatibility` 与 `allowed-tools`
- When: 调用标准解析入口
- Then: 可得到 `compatibility` 文本与 `allowedTools` 数组

### 场景 6：未知字段容错
- Given: frontmatter 包含规范外顶层字段（如 `unexpected-key`）
- When: 调用标准解析入口
- Then: 解析成功
- And: `warnings` 包含未知字段告警

### 场景 7：空必填字段容错
- Given: `name` 或 `description` 为空字符串
- When: 调用标准解析入口
- Then: 解析结果 `isValid=false`
- And: `issues` 包含 `missing_name` / `missing_description`（`severity=error`）

### 场景 8：allowed-tools 兼容输入
- Given: `allowed-tools` 为逗号分隔字符串或混合类型 YAML 数组
- When: 调用标准解析入口
- Then: 输出归一化后的 `allowedTools`
- And: 非字符串数组项产生 warning

## 验收标准
1. 新增 parser 单测覆盖上述 4 个场景。
2. 新增 parser 单测覆盖 `compatibility/allowed-tools`。
3. `SkillParser.parse` 行为兼容当前仓库既有 skills，不引入破坏性回归。
4. 新解析入口可被后续仓库扫描/导入逻辑复用。
5. `allowed-tools` 兼容输入测试与未知字段测试覆盖。
6. `skills parse` CLI 输出包含 `is_valid` 与 `issues` 字段。

## 实现约束
1. 保持 app 层编排定位，不引入 UI 侧耦合。
2. 解析层仅依赖已有 `Yams` 与基础模型。
3. 统一中文注释与错误/告警文案语义。

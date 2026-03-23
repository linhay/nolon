# Codex Advanced 配置保留现有 TOML 实现说明（2026-03-11）

## 问题定义
旧实现的结构化保存链路：

1. 读取 `config.toml`
2. 解码为 `CodexConfigToml`
3. 把 UI draft merge 到 typed model
4. 使用 `TOMLEncoder` 整文件编码回写

这个方案的问题是：
- 任何未建模字段、注释、顺序、额外 section 都会丢失。
- 当 `[agents]` 或 role table 含未知字段时，typed decode 可能整体失败，导致 `Advanced` UI 草稿为空。

## 本次设计
### 1. 加载与保存分离
- `loadSelectionsFromConfig()` 继续负责 `model` / `model_reasoning_effort` 的轻量读取。
- `loadConfigDraft()` 改为文本提取：
  - 直接按 section 解析原始 TOML 行
  - 提取 `Advanced` 页面已支持的键
  - 忽略未知字段但不报错

### 2. 保存改为增量 patch
- 新增 `CodexStructuredConfigPatchService`
- 输入：
  - 原始 TOML 文本
  - `CodexAdvancedStructuredDraft`
- 输出：
  - 仅改动受控键后的 TOML 文本

受控范围：
- 顶层：
  - `approval_policy`
  - `sandbox_mode`
  - `web_search`
  - `model_provider`
  - `profile`
  - `personality`
  - `model_reasoning_summary`
  - `model_verbosity`
- `[features]`
- `[agents]`
  - `max_threads`
  - `max_depth`
- `[agents.<role>]`
  - 结构化 UI 已支持的 role 字段

### 3. 初始化期禁止写回
- 新增 hydration 状态：
  - `isHydratingStructuredDraft`
  - `hasLoadedStructuredDraft`
- 所有控件的自动保存入口统一走 `scheduleStructuredSaveIfReady()`
- 只有完成首次草稿加载后，用户真实交互才会触发保存

## 取舍
- 没有继续沿用 typed round-trip，因为 `CodexConfigToml` 不是 lossless model。
- 没有为 `Advanced` 页面引入完整 TOML AST 依赖，本次实现采用轻量文本 patch，成本更低。
- 代价是受控 block 内部排版可能被归一化，但 block 外内容会保留。

## 测试策略
- 在 `CodexAdvancedConfigRoleDraftTests` 补三个回归：
  - patch 保留未知字段
  - 未加载完成前不保存
  - 结构化保存保留不受控 TOML

## 后续可扩展点
- 如果未来需要保留受控 block 内部注释与顺序，可把 patch service 升级为 AST 级编辑器。
- 如果 `Advanced` 页继续扩展更多键，新增字段时必须同时更新：
  - draft 提取
  - patch 生成
  - 回归测试

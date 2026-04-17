# Codex Sessions Usage 独立索引设计（2026-04-17）

## 背景
- `Codex Sessions` 现在已经支持：
  - row 级 usage 展示
  - section 组头 usage 聚合
  - 会话与会话组按 usage 排序
- 但 `loadSessionUsage(...)` 仍然对每个 session 走“整份 rollout 文件读取 + 逐行 usage reduce”路径。对于 3000+ 会话，这会把高频交互退化成后台持续解析与多轮重排。
- 2026-04-17 的独立索引评估已经收敛：
  - 在“排序/搜索也是常用功能”的前提下，第一优先级应是 `usage` 独立索引，而不是 `state projection` 或 `search`。

## 目标
1. 为 `Codex Sessions` 引入可丢弃的 `usage` 独立索引，优先优化：
   - 按 usage 排序
   - 组头 usage 展示
   - 已访问会话的 row usage 读取
2. 索引必须支持文件级差量更新，而不是每次都重扫整份 rollout。
3. 索引边界保持在 `CodexSessionStore` 服务层，对 ViewModel/UI 尽量透明。

## 非目标
1. 本轮不实现 `search` FTS。
2. 本轮不实现 `state projection` 独立索引。
3. 本轮不改 `snapshotStream / loadSnapshot / skeleton` 主扫描链路。
4. 本轮不追求实时强一致；索引允许“读取命中旧值，后台再修正”。

## 设计约束
1. 索引是可丢弃缓存，不是真源。
2. 真源仍然只有 rollout 文件。
3. 索引损坏、缺失或读取失败时，必须自动回退到现有全量解析。
4. 不能把 `usage` 强耦合进主 row/header 索引主链路。
5. 索引落盘位置使用 `Application Support/Nolon/codex-sessions/`，不放 `UserDefaults`。

## 方案总览

### 1. 新增独立索引组件
- 建议新增 `CodexSessionUsageIndex`（Provider 层内部类型）。
- 责任：
  - 维护 usage SQLite 索引文件
  - 基于 rollout 文件指纹判定 `cache hit / append delta / full rebuild`
  - 读写 `CodexSessionTokenTotals`

### 2. 存储位置
- 根目录：`~/Library/Application Support/Nolon/codex-sessions/`
- 数据库文件：`usage-index-v1.sqlite`
- 单库多 root：
  - 使用 `codex_home_path` 作为隔离键
  - 避免为每个 provider/codexHome 单独开数据库文件

### 3. 表结构

`usage_entries`

| 列 | 类型 | 说明 |
|---|---|---|
| `codex_home_path` | TEXT | `CODEX_HOME` 绝对路径 |
| `rollout_path` | TEXT | 相对 `codexHome` 的 rollout path |
| `absolute_rollout_path` | TEXT | 解析后的绝对路径，便于诊断 |
| `session_id` | TEXT | 从 `session_meta` 提取的 session id，可空 |
| `file_id` | INTEGER | 文件系统 inode / system file number，用于识别“原文件 append”与“文件替换” |
| `mtime_unix_ms` | INTEGER | 文件最后修改时间 |
| `size_bytes` | INTEGER | 文件大小 |
| `parsed_bytes` | INTEGER | 已解析到的字节偏移；用于 append tail 增量 |
| `last_model` | TEXT | 上次解析结束时的 model |
| `input_tokens` | INTEGER | totals.input |
| `cached_input_tokens` | INTEGER | totals.cached |
| `output_tokens` | INTEGER | totals.output |
| `updated_at_unix_ms` | INTEGER | 索引更新时间 |

约束：
- 主键：`(codex_home_path, rollout_path)`
- 辅助索引：`(codex_home_path, session_id)`

### 4. 读取策略
`CodexSessionStore.loadSessionUsage(...)` 改为：

1. 解析 rollout 绝对路径并读取 `absolute_path / file_id / mtime / size`
2. 查 `usage_entries`
3. 命中且 `absolute_path / file_id / mtime / size` 一致：
   - 直接返回 cached totals
4. 命中且满足以下 append 条件时走增量：
   - `absolute_path` 未变化
   - `file_id` 未变化
   - `size` 变大
   - `parsed_bytes == 旧 size`
   - `mtime >= 旧 mtime`
   - 且存在 `parsed_bytes/last_model/totals`
   - 从 `parsed_bytes` 开始只读取尾部新增内容
   - 继续调用现有 `reduceUsageLine(...)`
   - 覆盖索引行
5. 其他情况：
   - 回退全量解析
   - 覆盖索引行

### 5. 失效与删除
- rollout 文件不存在：
  - 返回 `nil`
  - 同时删除对应索引行
- rollout 文件变小、mtime 回退、读取失败、SQLite 损坏：
  - 放弃增量
  - 直接全量重建
- rollout 文件路径相同但 `file_id` 改变：
  - 视为文件被替换
  - 直接全量重建
- 本轮不做全库垃圾回收；只在“读到文件不存在”时局部删除

### 6. 与现有代码的接线点
- Provider：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift)
  - [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift)
- App：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)

接线原则：
- `CodexSessionsTabServicing` 协议先不改签名。
- 由 `CodexSessionStore.loadSessionUsage(...)` 内部切到 usage index。
- ViewModel 继续只感知 `CodexSessionTokenTotals?`，不感知索引来源。

## 攻击面检查

### 依赖失败
- SQLite 文件损坏或目录不可写：
  - 直接回退现有全量解析
  - 不阻塞功能正确性

### 规模放大
- 10x 会话量时，最先爆的是 usage 排序时的 rollout 解析队列。
- usage 索引正好切中这个瓶颈，因为它把“整文件反复读”降成“命中 stat + 单行查询”。

### 回滚成本
- 回滚非常低：
  - 关闭 usage index 接线
  - 删除 `usage-index-v1.sqlite`
  - 不触碰 rollout 真源

### 脆弱前提
- 最脆弱的前提是“rollout 大多数场景是 append，而不是整体重写”。
- 真实实现额外用 `file_id` 做护栏，避免同路径文件被替换后误走 tail append。
- 若该前提不成立，设计仍能工作，只是退化到“更多 full rebuild”，不会影响正确性。

## 测试策略

### Provider 单测
1. 首次读取 rollout 时，能创建 usage 索引并返回 totals。
2. 文件未变化时，第二次读取命中索引。
3. rollout 只 append 新 token line 时，只解析尾部并合并 totals。
4. rollout 被整体替换或截断时，回退全量重建。
5. rollout 文件删除时，返回 `nil` 并清掉索引行。

### App 回归
1. 现有 `CodexSessionsTabViewModelTests` 中 usage 排序与组头 usage 聚合用例继续通过。
2. 不要求本轮新增 UI 快照；本轮优化点在服务层性能路径，不改视图语义。

## 实施顺序
1. 先补 feature 规格。
2. 先补执行计划。
3. 先写 Provider 红灯测试。
4. 最小实现 usage index。
5. 跑定向测试。
6. 更新 memory，并执行 `qmd update && qmd embed`。

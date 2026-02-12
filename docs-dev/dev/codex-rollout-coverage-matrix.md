# Codex Rollout 解析覆盖矩阵

## 背景
`CodexGeneratedFilesParser` 负责解析：
- `~/.codex/sessions/**/*.jsonl`
- `~/.codex/archived_sessions/**/*.jsonl`
- 以及 `history.jsonl`、`config.toml` 等生成文件。

本矩阵用于标注“已类型化覆盖 / 兼容降级 / 待扩展”。

## 顶层 line.type 覆盖

| line.type | 解析结果 | 覆盖状态 | 说明 |
|---|---|---|---|
| `session_meta` | `.sessionMeta` | 已类型化 | 含 git 元信息 |
| `response_item` | `.responseItem` | 已类型化 | 子类型见下表 |
| `compacted` | `.compacted` | 已类型化 | 含 replacement_history |
| `turn_context` | `.turnContext` | 已类型化 | cwd/approval/sandbox/model |
| `event_msg` + `token_count` | `.tokenCount` | 已类型化 | 支持嵌套 `payload.type=token_count` |
| `event_msg` + 其他 | `.eventMsg` | 已类型化 | 常见 user/agent/error/warning/turn |
| `token_count` | `.tokenCount` | 已类型化 | 顶层 token_count |
| 其他未知 | `.other(type:)` | 兼容降级 | 不抛错，保留 type |

## response_item.type 覆盖

| response_item.type | 覆盖状态 | 说明 |
|---|---|---|
| `message` | 已类型化 | content 支持 input/output text、input image |
| `function_call` | 已类型化 | name/arguments/call_id |
| `function_call_output` | 已类型化 | output 保留结构化 JSON |
| `local_shell_call` | 已类型化 | status/action |
| `custom_tool_call` | 已类型化 | input 保留结构化 JSON（已修复字符串收窄） |
| `custom_tool_call_output` | 已类型化 | output 保留结构化 JSON（已修复字符串收窄） |
| `reasoning` | 已类型化 | summary/content 以 JSONValue 保留 |
| `web_search_call` | 已类型化 | status/action |
| `compaction`/`compaction_summary` | 已类型化 | encrypted_content |
| `ghost_snapshot` | 已类型化 | ghost_commit 结构保留 |
| 其他未知 | 兼容降级 | `.other(type:raw:)` |

## event_msg.type 覆盖

| event_msg.type | 覆盖状态 | 说明 |
|---|---|---|
| `token_count` | 已类型化 | 转 `.tokenCount` |
| `user_message` | 已类型化 | message/images/local_images/text_elements |
| `agent_message` | 已类型化 | 文本消息 |
| `error` | 已类型化 | 错误消息 |
| `warning` | 已类型化 | 警告消息 |
| `task_started`/`turn_started` | 已类型化 | model_context_window |
| `task_complete`/`turn_complete` | 已类型化 | last_agent_message |
| 其他未知 | 兼容降级 | `.other(type:payload:)` |

## 测试覆盖快照
- 文件：`libs/Providers/Tests/ProvidersTests/CodexTests/CodexGeneratedFilesParserTests.swift`
- 已覆盖场景：
  - `session_meta`
  - `token_count`（event_msg + nested event payload）
  - `response_item.message`
  - `response_item.function_call_output/local_shell_call/web_search_call/ghost_snapshot`
  - `response_item.custom_tool_call/custom_tool_call_output`（结构化）
  - `response_item.reasoning/compaction_summary`
  - `event_msg.user_message/agent_message/error/warning/task_started/task_complete/turn_complete`
  - unknown fallback（`event_msg.other`、top-level `.other(type:)`）
  - `compacted`
  - `history.jsonl`
  - `config.toml` / `managed_config.toml`
  - `sessions` + `archived_sessions` 文件加载
  - `CODEX_HOME` 全量文件入口加载（auth/history/config/managed_config/sessions）

## 当前状态
- 本轮待补强项已全部落地（task lifecycle、reasoning/compaction_summary、nested token_count）。
- 解析器新增 `loadAllGeneratedFiles(codexHome:includeArchived:)`，统一装配 Codex 生成文件解析入口，降低调用侧重复拼装逻辑。
- 补充 `includeArchived=false` 回归：统一入口在仅需活跃会话时不会读取 `archived_sessions`。
- 解析器内部增加 `FileName` 常量与通用文件加载 helper（`loadOptionalParsedFile` / `loadParsedListFile`），进一步减少重复路径与读取逻辑。

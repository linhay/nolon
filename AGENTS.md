# 项目知识库

**生成时间：** 2026-01-24
**项目：** Nolon（macOS SwiftUI 应用）

## 概览
Nolon 是一个面向 AI 编程助手的 macOS 技能管理器。项目采用 SwiftUI + Clean Architecture，核心关注点包括：
- 本地技能管理与安装。
- 提供商能力适配与 CLI 集成。
- 统一 UI 设计系统与组件复用。
- 本地化与工程化发布流程。

## 目录结构
```
.
├── AGENTS.md
├── build.sh                         # 自定义 CLI 构建/校验脚本
├── nolon.xcodeproj/                 # Xcode 工程
├── nolon/                           # 主应用（SwiftUI）
│   ├── DesignSystem/                # **必须**：颜色系统与可复用 UI 组件
│   ├── Skills/                      # 核心功能模块（Clean Architecture）
│   │   ├── Models/                  # 领域实体（不可变结构体）
│   │   ├── Infrastructure/          # 副作用层（文件、解析、安装）
│   │   └── Views/                   # SwiftUI 视图层（SplitView 模式）
│   ├── Resources/                   # 应用资源
│   ├── Localizable.xcstrings        # 主应用本地化资源
│   └── nolonApp.swift               # 入口点（@main）
├── libs/
│   ├── Providers/                   # 提供商能力与 CLI 集成（含 Codex 边界）
│   ├── NolonUI/                     # 共享 UI 组件库
│   └── NolonUIFoundation/           # UI 基础能力
├── nolonTests/                      # 单元与快照测试
├── nolonUITests/                    # UI 自动化测试
├── docs/                            # 发布说明与文档站点资源
├── scripts/                         # 脚本工具
├── design-proposals/                # 设计提案
└── memory/                          # 项目工作记录
```

## 最佳范式
- **一对一绑定**：1 个 UI 组件必须拥有 1 个对应的 ViewModel。
- **可观测性要求**：每个 ViewModel 必须使用 `@Observable`。
- **职责分离**：UI 组件只负责展示与交互；ViewModel 负责数据处理、状态管理与视图数据组装。
- **命名约定**：ViewModel 命名使用 `{组件名}ViewModel`，并与组件保持语义一致。

示例：

```swift
@Observable
final class NolonAccountsViewModel {}
```

在该范式下：
- UI 组件负责展示。
- `NolonAccountsViewModel` 使用 `@Observable` 提供状态可观测能力，并负责数据处理和组装。

## 工程约定
- **架构边界**：遵循 Models -> Infrastructure -> Views 分层。
- **Codex 边界**：Codex CLI / app-server 与 JSON-RPC 逻辑必须位于 `libs/Providers`；应用层只负责调用编排。
- **设计系统**：UI 颜色与组件能力优先复用 `DesignSystem` 与 `libs/NolonUI*`。
- **本地化**：新增文案统一进入 `Localizable.xcstrings`，不新增 `*.lproj` 资源文件。
- **问题求解策略**：优先查询可用 skills；不确定时先搜索资料或代码再结论，禁止硬猜。
- **优化策略**：性能或行为优化优先增加可观测日志，基于日志定位瓶颈后再实施优化。
- **日志最小标准**：关键路径日志至少包含 traceId（或请求标识）、耗时、关键输入摘要、结果状态（成功/失败）；失败场景需记录错误码或错误类型。

## 项目级 Skills
- 项目级约束与经验沉淀统一放在 `.agent/skills/`。
- 涉及 `Codex Sessions` 模块（会话列表、分组、搜索、用量、详情、缓存、扫描、CLI 对齐）时，先读取 `.agent/skills/codex-sessions-workstream.md`，再决定是否进入实现。
- 涉及稳定个人/团队偏好时，优先复用 `.agent/skills/preferences.md`，不要把同类规则重复散落到临时文档。

## Codex Sessions 共识
- `Codex Sessions` 的主目标是“大规模会话下稳定浏览”，不是实时全量刷新。
- 进入该模块时，先区分本次任务属于产品语义、性能/缓存、交互布局、还是诊断链路；涉及语义、缓存策略、信息架构调整时，先补 `docs-linhay/features/`、`docs-linhay/dev/` 或 `docs-linhay/plans/`，再改代码。
- 缓存策略默认遵循“先展示可用缓存，再后台 reconcile，再按 stale 条件刷新”，避免每次进入页面或 App 激活都全量重扫。
- 大列表场景下，排序与分组必须保证视觉稳定，禁止为了追求实时性导致 section/row 持续跳动、难以滚动。
- UI 细节调整不得绕开业务闭环：任何会影响分组、排序、详情、分享、用量口径、缓存命中的改动，都要先确认 Provider 层与 ViewModel 层边界。

## 执行检查清单
1. 新增或重构 UI 组件时，是否同步创建/维护 1 个对应 ViewModel。
2. ViewModel 是否使用 `@Observable`。
3. ViewModel 命名是否符合 `{组件名}ViewModel`。
4. UI 组件是否仅负责展示与交互，数据处理是否位于 ViewModel。
5. 代码是否遵循 Models -> Infrastructure -> Views 分层，且无反向依赖。
6. 涉及 Codex CLI / app-server / JSON-RPC 的逻辑是否仅放在 `libs/Providers`。
7. UI 颜色与组件是否优先复用 `DesignSystem`、`libs/NolonUI*`，避免重复实现。
8. 新增或修改文案是否已写入 `Localizable.xcstrings`，且未新增 `*.lproj` 文件。
9. 遇到不确定问题时，是否先查询可用 skills，并在必要时完成搜索验证后再输出结论。
10. 优化任务是否先通过日志或指标定位，再进行针对性优化。
11. 关键路径日志是否满足最小标准（标识、耗时、输入摘要、结果状态、错误信息）。
12. 涉及 `Codex Sessions` 时，是否先对齐 `.agent/skills/codex-sessions-workstream.md` 与相关 `docs-linhay` 文档，再进入实现。

## 常用命令
```bash
# 测试（默认）
# 后续测试统一使用 xcodebuild；除非用户明确要求，不使用 swift test
xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'

# 校验构建
./build.sh

# 构建 Release
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## 本地化流程
使用 Agent 翻译新增文案时：
1. **提取**：运行 `python3 nolon/scripts/extract_missing_translations.py` 生成 `missing_translations.json`。
2. **翻译**：将 JSON 内容交给 AI Agent 生成翻译。
3. **保存**：将 Agent 输出保存为 `nolon/scripts/translated_items.json`。
4. **导入**：运行 `python3 nolon/scripts/import_translations.py` 更新 `Localizable.xcstrings`。

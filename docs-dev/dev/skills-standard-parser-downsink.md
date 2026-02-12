# Skills 标准解析下沉（ProviderCatalog）

## 背景

为满足“nolon 核心能力下沉到 CLI/SDK（`libs/Providers`）”目标，`SKILL.md` 标准 frontmatter 解析不能继续只留在 App 层。
本次将标准解析能力下沉到 `ProviderCatalog`，并让远程仓库目录发现直接复用该能力。

## 本次改动

1. 新增 `ProviderCatalog.SkillSpecificationParser`
   - 文件：`libs/Providers/Sources/ProviderCatalog/SkillSpecificationParser.swift`
   - 能力：
     - 使用 `Yams` 解析 frontmatter（支持 block scalar、多行文本、YAML list/object）
     - 解析 `name`、`description`、`license`、`compatibility`、`allowed-tools`、`metadata`、`argument-hint`
     - 产出 `warnings`（缺失字段、命名不合规、目录名不一致、metadata 值非字符串等）
     - 提供 `extractSkillDisplayName(from:fallbackDirectoryName:)`

2. 远程仓库资源发现接入标准解析
   - 文件：`libs/Providers/Sources/ProviderCatalog/RemoteGitRepositorySupport.swift`
   - 变更：
     - `detectSkillsDirectories` 在读取目录中 `SKILL.md` 时优先使用标准 `name` 作为展示名
     - 无法解析时回退目录名
     - `skillNames` 做排序，确保结果稳定

3. App 层复用下沉能力
   - 文件：`nolon/Skills/Infrastructure/SkillParser.swift`
   - 变更：
     - `parseStandardMetadata` 改为委托 `ProviderCatalog.SkillSpecificationParser`
     - 避免 App 层与库层双份规则漂移

4. 解析健壮性增强（第二轮）
   - 文件：`libs/Providers/Sources/ProviderCatalog/SkillSpecificationParser.swift`
   - 变更：
     - 增加未知顶层字段识别（`unknown top-level field` warning）
     - `name/description` 空字符串识别与告警（`empty ... in frontmatter`）
     - `allowed-tools` 兼容解析：
       - 空白/逗号分隔字符串
       - YAML 字符串数组
       - 混合类型数组（非字符串转字符串并告警）

## 测试

1. `libs/Providers/Tests/ProvidersTests/SkillSpecificationParserTests.swift`
   - 标准字段解析
   - 缺省 `name` 回退目录名
   - 展示名提取优先 `name`
   - 多行 `description`（YAML block）解析
   - `allowed-tools` YAML 数组解析
   - `metadata` 混合类型告警
   - 未知顶层字段告警
   - 空必填字段告警与默认值回退
   - `allowed-tools` 逗号分隔与混合数组兼容

2. `libs/Providers/Tests/ProvidersTests/RemoteGitRepositorySupportTests.swift`
   - 验证 agent-skills 风格目录发现
   - 验证 `skillNames` 使用标准 `name`

3. `nolonTests/SkillParserSpecificationTests.swift`
   - 验证 App 侧标准解析与兼容回退行为保持一致

## 结论

`SKILL.md` 标准解析已经完成“核心下沉”：库层可独立复用，App 仅负责编排与展示。
后续 CLI 化时可直接复用 `ProviderCatalog` 的同一解析能力，避免再实现一套。 

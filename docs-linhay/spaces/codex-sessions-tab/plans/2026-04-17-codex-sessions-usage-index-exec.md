# Codex Sessions Usage 独立索引执行计划（2026-04-17）

## 范围
- 本轮只实现 `usage` 独立索引。
- 不处理 `search` FTS。
- 不处理 `state projection` 独立索引。
- 不改 View 层结构与交互语义。

## BDD 验收
1. Given 某条 session 的 rollout 首次被读取
   When `CodexSessionStore.loadSessionUsage(...)` 完成
   Then 返回正确 totals
   And usage 索引库中写入对应 entry。

2. Given 同一条 rollout 文件没有变化
   When 第二次读取 usage
   Then 直接命中索引
   And 不再重走整文件全量解析。

3. Given rollout 文件只在尾部 append 新的 token_count 事件
   When 再次读取 usage
   Then 只解析新增尾部
   And 返回合并后的最新 totals。

4. Given rollout 文件被整体替换或截断
   When 再次读取 usage
   Then 放弃增量
   And 回退到全量重建
   And 索引 entry 被覆盖成最新状态。

5. Given rollout 文件已经不存在
   When 读取 usage
   Then 返回 `nil`
   And 清理对应 usage 索引 entry。

6. Given `Codex Sessions` 现有 usage 排序与组头 usage 展示测试已存在
   When 接入 usage 独立索引后
   Then 这些行为回归测试继续通过。

## TDD 计划

### 红灯
1. `CodexSessionStoreTests`
   - 新增“首次读取会写索引”用例
   - 新增“未变化文件命中索引”用例
   - 新增“append tail 增量合并”用例
   - 新增“truncate/replace 回退全量”用例
   - 新增“文件缺失清索引”用例
2. 运行现有：
   - `CodexSessionsTabViewModelTests` 中 usage 排序相关用例

### 绿灯
1. 新增 `CodexSessionUsageIndex`
2. `CodexSessionStore.loadSessionUsage(...)` 改为先查 usage index，再决定 `cache hit / delta / rebuild`
3. 保持 `CodexSessionsTabServicing` 对上层接口不变

## 实施步骤
1. 补 feature 规格，锁定边界。
2. 补 dev 设计文档，锁定 schema、失效策略和存储位置。
3. 补 Provider 红灯测试。
4. 实现 usage index 与接线。
5. 跑定向测试：
   - `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
6. 更新 memory。
7. 执行 `qmd update && qmd embed`。

## 风险
- `CodexSessionStoreTests` 目前以 snapshot/rewrite 为主，usage index 会把更多文件级 fixture 和 SQLite 断言带进来，测试夹具要保持局部，不要污染既有 case。
- `Application Support` 路径在测试中不能直接依赖真实用户目录，必须提供可注入 root。
- 如果 append 增量读取实现不稳，允许先保留“命中缓存 / 全量重建”两档，再补 tail 增量；但必须先在文档里同步缩小范围。

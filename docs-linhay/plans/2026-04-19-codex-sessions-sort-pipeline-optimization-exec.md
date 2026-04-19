# 2026-04-19 Codex Sessions 排序链路优化执行计划

## 背景
- projection cache 已经把“列表出现”提快了。
- 当前剩余痛点是“排序完成较慢”，尤其是在首屏 hydrate 大量 rows 后。

## 本轮目标
1. 去掉 `upsert -> bucket sort` 的重复排序。
2. 把 section rows 排序职责集中到 `makeSectionState(...)`。
3. 保持 `recent/usage` 排序结果不变。
4. 通过定向测试验证首屏顺序稳定与 usage 排序回归。

## BDD 场景

### 场景 1：recent 模式下 usage 回填不改序
- Given 首屏按 recent 展示会话
- When usage 在后台异步完成
- Then 当前 sections 和 rows 顺序保持不变

### 场景 2：usage 模式下行排序仍正确
- Given 同组会话存在不同 usage
- When 切换到 `usage`
- Then 行顺序按 usage 从高到低排列

### 场景 3：usage 模式下组排序仍正确
- Given 不同组的 usage 总量不同
- When 切换到 `usage`
- Then 组顺序按聚合 usage 从高到低排列

## TDD 步骤
1. 先在 `CodexSessionsTabViewModelTests` 新增 `recent` 模式稳定性测试。
2. 运行定向测试，确认红灯或至少覆盖当前行为。
3. 修改 `CodexSessionsTabViewModel`：
   - `insert(...)` 取消排序
   - `makeProjectSectionStates()` / `makeProviderSectionStates()` 取消重复排序
   - `makeSectionStates(from:)` 取消重复排序
4. 回归现有 usage 排序测试与缓存加载测试。

## 验证命令
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -derivedDataPath /tmp/nolon-codexsessions-sortopt -only-testing:nolonTests/CodexSessionsTabViewModelTests`

## 风险控制
- 严格只改会话排序相关文件。
- 不触碰已存在的会话详情 UI 改动文件。
- 若测试显示 usage 排序退化，优先回到 `makeSectionState(...)` 的单点排序实现，不重新把排序塞回 `insert(...)`。

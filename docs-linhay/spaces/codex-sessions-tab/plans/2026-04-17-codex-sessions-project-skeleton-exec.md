# Codex Sessions Project Skeleton 执行计划

日期：2026-04-17
范围：`Codex Sessions` 在 3000+ 会话下的 project-first 稳定加载

## 目标
1. 先发布 project skeleton，避免 section 在 streaming 扫描中持续插入和重排。
2. skeleton 发布后，渐进填充真实 session rows。
3. 保持 section identity 与排序稳定，减少 SwiftUI 列表跳动。

## BDD
1. Given 会话很多且扫描时间较长
   When 页面开始加载
   Then 先稳定展示项目骨架 section。

2. Given 某个项目仍未补齐真实 rows
   When 用户浏览列表
   Then 该项目仍可见，但 section 内 rows 为空。

3. Given 后续 stream 补齐某项目的真实 rows
   When section 更新
   Then 复用既有 section id，并从占位态切到真实态。

4. Given refresh 发生
   When 新一轮扫描开始
   Then 仍优先发布 skeleton，列表不回退成持续跳动状态。

## 实施步骤
1. 文档固化
   - 更新 feature 文档，写清两阶段加载与产品约束。
   - 新建本执行计划文档。

2. 测试先行
   - `CodexSessionsTabViewModelTests`
   - `CodexSessionStoreTests`
   - 先写失败用例覆盖 skeleton 发布、空 rows、section id 复用、稳定排序。

3. Provider 实现
   - 新增 `CodexSessionProjectSkeleton`
   - 在 `CodexSessionStore` 中实现 project skeleton 预扫描
   - 只读取 rollout 首条 `session_meta`，不提前读取完整状态索引

4. ViewModel 实现
   - 新增 preloading service protocol
   - load 时先取 skeleton，再消费 snapshot stream
   - placeholder section 跳过 selection repair 与 usage 预取

5. 验证与收尾
   - 定向跑 ViewModel 与 Provider 测试
   - 写入 `docs-linhay/memory/2026-04-17.md`
   - 执行 `qmd update && qmd embed`

## 风险
1. project skeleton 与真实 section 合并时如果 id 生成规则不一致，会再次触发重排。
2. 若 skeleton 顺序和真实 section 顺序算法不一致，后续 rows 回填仍可能造成局部抖动。
3. refresh 与 usage 异步回填并发时，需要避免 placeholder section 被误选中或误触发 usage 任务。

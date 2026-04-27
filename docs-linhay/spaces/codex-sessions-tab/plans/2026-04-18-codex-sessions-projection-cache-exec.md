# 2026-04-18 Codex Sessions Projection Cache 执行计划

## 目标
1. 让 `Codex Sessions` 首屏优先从磁盘缓存恢复可浏览内容。
2. 把当前 3000+ 会话下约 2s 的首屏等待，拆成“立即展示缓存 + 后台刷新”。
3. 保证缓存层可丢弃、失败可降级、行为可回滚。

## BDD
1. Given 已存在上次成功写入的 `session_snapshot`
   When 用户进入 `Codex Sessions`
   Then 页面立即显示缓存会话列表。

2. Given 只有 `project_skeleton` 缓存，没有完整会话缓存
   When 用户进入页面
   Then 页面先显示项目概览，再后台补真实会话。

3. Given 缓存不存在或损坏
   When 用户进入页面
   Then 页面自动回退现有扫描链路，不中断使用。

4. Given 页面已经加载过且最近刷新时间未过期
   When App 从后台切回前台
   Then 不会无脑重扫。

## TDD

### 红灯测试
1. `CodexSessionStoreTests`
   - 新增 projection cache 读写测试
   - 新增 projection cache invalidation 测试
   - 新增 schema mismatch 忽略测试
2. `CodexSessionsTabViewModelTests`
   - 新增 cached snapshot 首屏应用测试
   - 新增 cached skeleton 兜底测试
   - 新增 app activation stale-check 测试

### 绿灯实现
1. 新增 `CodexSessionProjectionCache`
   - 管理 SQLite 打开、表创建、JSON 读写、失效
2. 改造 `CodexSessionStore`
   - 提供 cached snapshot/skeleton 读取能力
   - 在真实扫描成功后写回缓存
3. 改造 `CodexSessionsTabViewModel`
   - `reload(.initial)` 先应用磁盘缓存
   - `refreshOnAppActivationIfNeeded()` 改走 stale-check

## 实施顺序
1. 新建文档与计划
2. 先补 Provider 红灯测试
3. 最小实现 projection cache
4. 接线到 ViewModel 首屏加载
5. 跑定向测试与 benchmark
6. 更新 memory 并执行 `qmd update && qmd embed`

## 验证命令
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- `./libs/Providers/.build/release/nolon codex session benchmark --provider codex`

## 风险
1. 若缓存 payload 设计过重，SQLite 读写可能引入新的阻塞。
2. 若 ViewModel 初次加载先后应用 skeleton 与 snapshot 顺序不当，可能出现闪烁。
3. 若缓存失效时机遗漏，rewrite 后可能短暂显示旧数据。

## 完成定义
1. 技术文档与执行计划已落盘。
2. Provider / ViewModel 定向测试通过。
3. 会话页进入时能先显示磁盘缓存，再后台刷新。
4. App 激活不再每次无脑刷新。

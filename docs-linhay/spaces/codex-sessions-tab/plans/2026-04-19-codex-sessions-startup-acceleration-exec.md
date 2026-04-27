# 2026-04-19 Codex Sessions Startup Acceleration Exec

## 背景
- 用户目标非常明确：会话页启动更快，且刷新不需要过于实时。
- 当前已有 projection cache，但命中缓存后仍可能继续做真实扫描，导致启动期仍有明显后台负担。

## 本轮目标
1. 为 projection cache 增加 `freshness + dirty` 判定。
2. 命中 clean + fresh cache 时，初次进入会话页直接结束，不做本轮 reconcile。
3. App 启动后后台预热 dirty / stale Codex provider。
4. 文件变化只标记 dirty，不实时重扫。

## 非目标
1. 不引入独立 `sessions-index.sqlite`
2. 不做搜索 FTS
3. 不改变会话页排序/分组语义

## BDD 场景

### 场景 1：clean cache 首屏直出
- Given cached snapshot 已存在
- And projection status = clean
- And cache 未超过 freshness 阈值
- When 用户进入会话页
- Then 页面直接显示缓存
- And `loadSnapshot` / `snapshotStream` 都不会被调用

### 场景 2：dirty cache 触发后台校准
- Given cached snapshot 已存在
- And projection status = dirty
- When 用户进入会话页
- Then 页面先显示缓存
- And 后台执行一次稳定 snapshot reload

### 场景 3：watcher 标脏
- Given App 正在运行
- When 监听路径发生变化
- Then projection status 被标记为 dirty
- And 不会立刻触发 UI 重扫

### 场景 4：warmup 跳过 clean provider
- Given App 启动
- When warmup service 执行
- Then clean + fresh provider 不会触发预热

## TDD 计划

### 红灯测试
1. `CodexSessionStoreTests`
   - 新增 projection status 读写测试
   - 新增 `markDirty` 测试
   - 新增 snapshot 持久化后清 dirty 测试
2. `CodexSessionsTabViewModelTests`
   - 新增 clean cached snapshot 跳过 reconcile 测试
   - 新增 dirty cached snapshot 继续 reconcile 测试
3. 新增 warmup / watcher 定向测试
   - 路径变化后只标脏
   - clean provider warmup 跳过

### 绿灯实现
1. Provider
   - 扩展 `CodexSessionProjectionCache` 的 status 能力
   - `CodexSessionStore` 暴露缓存状态查询与标脏接口
2. App/ViewModel
   - `CodexSessionsTabViewModel` 在 `initial load` 命中缓存后按 status 决定是否短路
   - 新增 `CodexSessionsWarmupService`
   - 新增 `CodexSessionsProjectionWatcher`

## 实施顺序
1. 先补 Provider status 测试
2. 最小实现 projection status
3. 补 ViewModel 缓存短路测试
4. 实现 ViewModel freshness/dirty gate
5. 接入 watcher
6. 接入 warmup service
7. 跑定向测试
8. 更新 memory 与 qmd

## 验证命令
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`

## 风险
- watcher 路径如果过宽，可能造成无意义 dirty 抖动，需要 debounce。
- clean 判定如果过于激进，可能短时间展示旧缓存；这是本轮接受的 tradeoff。
- warmup 需要确保不影响启动主线程。

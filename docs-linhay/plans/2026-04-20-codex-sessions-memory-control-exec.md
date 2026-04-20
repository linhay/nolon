# Codex Sessions 内存收敛执行计划（2026-04-20）

## BDD 场景

### 场景 1：稳定 rollout 复用 metadata cache
- Given usage index 已缓存 rollout 的 usage 与 timeline metadata，且文件未变化
- When 再次读取 usage 或 timeline
- Then store 直接命中缓存，不再重扫 rollout 文件

### 场景 2：timeline 正确性不回退
- Given rollout 中存在首条事件与最后活动时间
- When 加载详情 timeline
- Then 返回值与现有行为保持一致

### 场景 3：缺少时间戳时仍有降级结果
- Given rollout 中没有可解析的时间戳
- When 加载详情 timeline
- Then `startedAt` 保持为空，`lastActivityAt` 回退到文件 `mtime`

## 执行步骤
1. 先补失败测试：
   - `ProvidersTests`：usage/timeline metadata cache 回归场景。
2. 实现 provider 层流式读取与 metadata cache 扩展。
3. 复查 `loadSessionTimeline` 调用链，确保详情页也复用同一层缓存。
4. 跑 `ProvidersTests` 与 app 工程构建验证。
5. 更新 `docs-linhay/memory/2026-04-20.md`，执行 `qmd update && qmd embed`。

## 实际执行结果
1. 已补 `ProvidersTests`，覆盖 “usage 已索引且文件未变化时 timeline 直接 cache hit”。
2. 已新增 `CodexRolloutLineReader`，usage 解析切到流式逐行读取。
3. 已扩展 `CodexSessionUsageIndex`，同条索引记录缓存 `usage + timeline metadata`。
4. 已把 `loadSessionTimeline` 改为复用 usage index。
5. `CodexSessionsTabViewModelStore` 淘汰策略已从本轮范围移除，原因是运行时析构不稳定。

## 风险
- 扩展 usage index schema 时，需要兼容已存在数据库。
- timeline 改走 usage index 后，必须保证“未预先加载 usage”的详情展开也能正确回填索引。
- `CodexSessionsTabViewModelStore` 的析构/淘汰 crash 仍未根治，需要后续单独定位。

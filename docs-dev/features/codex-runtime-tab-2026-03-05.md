# Codex Runtime Tab 接入（2026-03-05）

## 目标
- 在 `codex` 与 `codexXcode` Provider 详情页新增 `Runtime` Tab。
- 让用户在 App 内直接查看运行中 Codex 进程、执行停止/强制停止，并查看指定 PID 的系统日志。

## 范围
- 包含：
  - Provider tab 配置新增 `runtime`
  - UI 新增 `CodexRuntimeTabView`
  - Runtime 进程诊断与操作 ViewModel
  - PID 日志读取能力（`/usr/bin/log show`）
- 不包含：
  - runtime inspect/restart
  - 跨机器或远程运行时管理

## BDD 验收场景
1. Given provider 为 `codex`，When 渲染可用 tabs，Then `runtime` 出现在 `usage` 后一位。
2. Given provider 为 `codexXcode`，When 渲染可用 tabs，Then `runtime` 出现在 `binary` 后一位。
3. Given runtime 列表可用，When 进入 Runtime Tab，Then 展示进程列表、诊断信息、日志区域。
4. Given 用户对 PID 执行 stop/force stop，When 命令完成，Then 页面刷新并显示执行结果摘要。
5. Given PID 日志查询失败，When 刷新日志，Then 仅日志区域报错，不影响进程列表与诊断展示。

## 测试要求
- 新增/更新单测并通过：
  - `CodexRuntimeTabConfigurationTests`
  - `CodexRuntimeTabViewModelTests`
  - `CodexPIDSystemLogServiceTests`

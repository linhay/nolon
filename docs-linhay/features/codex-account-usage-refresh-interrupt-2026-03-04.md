# Codex 账号与用量刷新状态与中断刷新修复（2026-03-04）

## 背景
- 在 `账号与用量` 页中，账号卡片右上角刷新指示会在请求完成后继续显示。
- 头部 `刷新` 按钮在刷新进行中无法稳定中断并再次触发刷新。

## 目标
1. 卡片刷新态只覆盖“网络/数据拉取阶段”，请求结束后立即消失。
2. 头部 `刷新` 按钮支持：刷新中点击可中断；中断后可再次刷新。

## BDD 场景
1. Given 某账号正在刷新，When 拉取请求已经返回，Then 卡片右上角刷新态应立即清除。
2. Given 头部刷新正在进行，When 用户再次点击刷新，Then 当前刷新任务被中断，按钮状态回到可再次触发。
3. Given 刚中断过一次刷新，When 用户再次点击刷新，Then 新一轮刷新可以正常启动，不被上一次任务回调覆盖。

## 验收标准
- `codexRefreshingAccountIds` 在 fetch 结果返回后立即移除对应账号 ID。
- 头部刷新状态由会话 ID 保护，旧任务完成不会覆盖新任务状态。
- 以下测试通过：
  - `ProviderUsageViewModelManualRefreshTests.testBDD_GivenAccountRefreshCompletes_WhenRefreshingCodexAccount_ThenRefreshingStateClears`
  - `ProviderUsageViewModelManualRefreshTests.testBDD_GivenHeaderRefreshInProgress_WhenTappingRefreshAgain_ThenCanInterruptAndRefreshAgain`

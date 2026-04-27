# Clawhub 远程列表 429 限流重试（2026-03-12）

## 背景
- 用户在资源中心拉取远程 skill 列表时，日志出现：
  - `Remote list failed. kind=skill baseURL=https://clawhub.ai error=commandFailed("Remote list failed with status 429")`
- 影响：
  - 短时限流会直接变成前台失败，用户无法看到列表数据。
  - 下载链路已有同 host 的 429 重试，列表链路行为不一致。

## 目标
- 为远程列表请求补齐与下载一致的 429 重试策略。
- 在不引入域名镜像回退的前提下，优先消化短时限流。

## BDD 验收场景
1. Given 远程 skill 列表首次请求返回 `429` 且随后恢复，When 资源中心再次发起同一列表请求，Then 同 host 自动重试一次并成功返回列表。
2. Given 远程 skill 列表连续返回 `429`，When 达到重试上限，Then 保留失败结果并返回 `Remote list failed with status 429`。
3. Given 远程列表请求遇到 TLS/连接类错误，When 请求失败，Then 仍保持当前行为，不做额外镜像回退。

## 非目标
1. 本次不新增指数退避或跨域名镜像切换。
2. 本次不改动资源中心文案，仅修复底层列表请求健壮性。

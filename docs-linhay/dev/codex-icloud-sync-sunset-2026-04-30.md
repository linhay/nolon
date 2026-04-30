# Codex iCloud Sync Sunset

日期：2026-04-30

## 背景

`2.1.20` 的线上启动崩溃来自 CloudKit 启动链路与签名/Provisioning Profile 组合不匹配。虽然此前已经补了 entitlement 预检和官方签名链路，但产品决策变更为短期内直接下线 Codex iCloud 同步功能，避免继续承担运行时、签名和分发复杂度。

## 本次策略

本次不是只做“缺能力时降级”，而是做“产品级关闭”：

1. `CodexiCloudSyncCloudKitRuntimeSupport.isProductEnabled = false`
2. 启动期 `CodexiCloudSyncService` 不再初始化 CloudKit live coordinator
3. 高级配置页不再展示 `Cloud Sync` 设置区块
4. 账号卡片不再展示任何云同步 tag / trailing text
5. `nolon.entitlements` 清空，不再声明 `CloudKit` / `APS`

## 验收点

1. 启动路径不会再触发 CloudKit bootstrap
2. 高级配置页看不到 `Cloud Sync` / `iCloud 同步`
3. 账号卡片即使存在历史 cloud sync state，也不再展示云同步状态文案
4. 定向回归测试通过：
   - `CodexCloudSyncPlacementTests`
   - `CodexiCloudSyncPresentationTests`

## 后续

如果未来恢复该功能，不能只改一个布尔值，需要同时重新评估：

1. CloudKit runtime 行为
2. entitlements / provisioning profile / notarization 链路
3. UI 入口与账号状态展示
4. 线上数据迁移与灰度策略

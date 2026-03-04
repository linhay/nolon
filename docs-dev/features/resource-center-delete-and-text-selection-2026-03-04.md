# 资源中心删除能力与文本可选（2026-03-04）

## 背景
资源中心已支持 Skills / Workflows / MCP 三类远程资源安装，但已安装卡片缺少统一删除入口，且页面文本无法统一选中复制。

## 范围
1. Skills / Workflows / MCP 的 Installed 卡片菜单新增 Delete。
2. Delete 触发删除目标选择：
- 单 Provider 删除
- 全部 Provider + 全局缓存删除
3. 批量删除策略：部分成功，汇总失败信息。
4. 资源中心页面文字支持选择复制。

## 非范围
1. 不改动 Provider 详情页删除逻辑。
2. 不新增新的仓库来源类型。

## BDD 验收场景
1. Given 已安装 Skill，When 在卡片菜单选择 Delete 并选择单 Provider，Then 仅该 Provider 卸载。
2. Given 已安装 Workflow，When 选择全部 Provider + 全局缓存，Then 所有 Provider 卸载并尝试删除全局缓存。
3. Given 多 Provider 删除中存在失败，When 删除执行完成，Then 返回部分成功并展示失败明细。
4. Given 资源中心任意文本，When 用户拖拽选择，Then 可复制文本。

## 验收证据
1. 单元测试：`nolonTests/ResourceDeletionCoordinatorTests.swift`
2. UI 截图目录：`screenshots/20260304/resource-center/`

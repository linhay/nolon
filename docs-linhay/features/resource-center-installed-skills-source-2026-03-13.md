# 资源中心已安装技能来源对齐（2026-03-13）

## 背景
- 当前资源中心 `Skills` 页的卡片数据来自当前选中的 repository 查询结果。
- 安装状态 `Installed` 则来自全局技能路径 `~/.nolon/skills` 或 provider 扫描结果。
- 当一个技能已经安装到全局路径，但当前 repository 查询结果里没有它时，卡片会显示“已安装”语义，却不会出现在资源中心列表里。

## 目标
- `Resource Center / Skills` 的 `Installed` 分区应以已安装技能集合为准。
- 当前 repository 返回的技能列表与已安装技能列表需要合并去重，避免已安装技能被当前来源过滤掉。
- 同 slug 同时存在于当前 repository 结果和已安装集合时，优先使用当前 repository 的远端元数据。

## BDD 验收
1. Given 技能 `harmony-next` 已安装到 `~/.nolon/skills/harmony-next`
   And 当前 repository 查询结果不包含 `harmony-next`
   When 打开 `Resource Center / Skills`
   Then `Installed` 分区仍显示 `harmony-next` 卡片

2. Given 技能 `harmony-next` 已安装到全局路径
   And 当前 repository 查询结果也包含 `harmony-next`
   When 打开 `Resource Center / Skills`
   Then 列表中只显示一张 `harmony-next` 卡片
   And 该卡片优先使用当前 repository 返回的元数据

3. Given 当前 provider 仅安装了部分全局技能
   When 打开 provider 绑定的 `Resource Center / Skills`
   Then `Installed` 分区仅显示该 provider 已安装的技能
   And 卡片详情仍来自全局技能缓存与当前 repository 结果的合并

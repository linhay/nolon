# 主站与衍生站视觉解耦（2026-03-04）

## 背景
当前 GitHub Pages 主站与 leaderboard 衍生项目在视觉表达上边界不清，用户容易将主站理解为数据看板页，而不是 Nolon 主产品入口。

## 目标
1. 主站（`docs/`）回归产品叙事：主控制台与核心能力优先。
2. 衍生项目（`projects/leaderboard-template/.site`）保持独立定位：社区数据看板模板。
3. 在主站中保留生态入口，但降低层级，避免喧宾夺主。

## 非目标
1. 不调整 leaderboard 的数据逻辑或排序口径。
2. 不新增后端能力或 API。
3. 不修改主站事实口径（例如 provider 覆盖、插件定位等）。

## BDD 验收场景
### 场景 1：首次访问识别主站定位
- Given 用户首次进入主站首页
- When 浏览 Hero 与前两屏内容
- Then 能明确识别该页面是 Nolon 主产品页面，而非排行榜页面。

### 场景 2：生态入口可达但非主叙事
- Given 用户在主站浏览到生态区块
- When 查看标题与说明
- Then 能理解 leaderboard-template 是可 fork 的衍生模板项目。

### 场景 3：移动端可读
- Given 用户使用 375px 宽度设备访问
- When 浏览导航、Hero、核心能力区块
- Then 不出现横向滚动，主要按钮点击区域不小于 44px。

## 方案约束
1. 先改 `docs-dev/features/`，再改代码。
2. 保持锚点 id 稳定，避免外链失效。
3. 保持中英双语切换能力；新增文案必须补齐双语 key。
4. 仅改主站 `docs/`，不变更衍生站实现。

## 交付清单
1. `docs/index.html`：重排信息层级，生态区块降级为次级展示。
2. `docs/assets/css/site.css`：重建主站视觉 token 与排版节奏（Editorial Tech）。
3. `docs/assets/js/site.js`：补齐新增 i18n key 并保持导航激活逻辑。
4. 测试：新增主站结构与 i18n 合同测试。
5. 记忆：记录本次关键决策并更新 qmd 索引。

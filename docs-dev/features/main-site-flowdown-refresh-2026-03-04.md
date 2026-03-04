# 主站 Flowdown 风格重构（2026-03-04）

## 背景
当前主站信息密度偏高、卡片噪音较多，用户对主产品定位识别不够快。目标是参考 `flowdown.ai` 的 landing 节奏，重构主站视觉与文案表达。

## 目标
1. 主站改为产品叙事优先，首屏清晰传达 Nolon 核心价值。
2. 保留双语切换并保证中英文文案一致可用。
3. 精简页面信息架构到 7 个主区块，降低视觉密度。
4. 明确 ecosystem 是衍生项目入口，不作为主叙事中心。

## 非目标
1. 不调整 `projects/leaderboard-template/.site` 的代码和交互。
2. 不新增后端接口或服务端逻辑。
3. 不变更主产品能力事实口径（如 provider 覆盖与插件定位）。

## 信息架构
1. hero
2. trust-strip
3. quick-start
4. console + resource-center
5. capabilities（合并 providers/codex/plugins）
6. architecture
7. ecosystem + download + faq

## BDD 验收
### 场景 1：产品定位识别
- Given 用户首次访问主站
- When 浏览首屏和下一屏
- Then 10 秒内可理解这是 Nolon 主产品页面

### 场景 2：双语一致
- Given 用户切换语言
- When 浏览所有主区块
- Then 不出现 key 泄漏，文案完整切换

### 场景 3：生态项目降级展示
- Given 用户浏览 ecosystem 区块
- When 阅读区块标题与说明
- Then 明确其为衍生模板项目

### 场景 4：移动端可用性
- Given 用户使用 375px 宽度设备
- When 浏览首页
- Then 无横向滚动，主要按钮点击区域 >= 44px

## 交付
1. `docs/index.html`：结构重排与新文案。
2. `docs/assets/css/site.css`：新视觉 token 与排版节奏。
3. `docs/assets/js/site.js`：新增/调整 i18n key 和导航兼容。
4. 测试：结构合同和 i18n 完整性测试。

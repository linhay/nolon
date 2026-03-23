# Clawhub 链接导入与添加仓库弹窗文本可选中（2026-03-05）

## 背景
- 用户通过 `https://clawhub.ai/<owner>/<slug>` 链接进入资源中心时，当前流程会误走 Git 仓库导入，导致克隆失败。
- 添加仓库弹窗中的错误文本和说明文本不可选中，影响复制排障。

## 验收场景（BDD）
1. Given 用户打开 `https://clawhub.ai/steipete/gemini`  
   When 资源中心接收到该链接  
   Then 不弹出“添加仓库”Git 导入弹窗  
   And 自动切换到 Clawdhub 资源源  
   And 搜索框自动填入 `gemini` 以便直接安装。

2. Given 用户打开普通 Git 地址（如 `https://github.com/acme/repo`）  
   When 资源中心接收到该链接  
   Then 保持原有 Git 导入流程（弹出添加仓库弹窗并预填 URL）。

3. Given 用户在“添加仓库”弹窗中看到错误文本或说明文本  
   When 用户尝试拖选文本  
   Then 文本可被选中并复制。

4. Given 用户打开无法识别的导入链接  
   When 资源中心接收到该链接  
   Then 不触发 Git 添加仓库弹窗  
   And 在资源中心显示可复制的错误提示文案。

## 非目标
- 本次不实现 Clawhub 链接“一键自动安装”（仍由用户确认并点击安装）。
- 本次不改变 Git 仓库同步策略与鉴权逻辑。

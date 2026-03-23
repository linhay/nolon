# Gemini 用量页去掉激活账号重复展示（2026-03-12）

## 背景
- Gemini 用量页在存在账号卡时，会在账号列表下方再渲染一张当前激活账号的用量快照卡。
- 由于 Gemini 的用量数据只针对当前激活账号，这两张卡展示的是同一账号，用户会误以为出现了两个相同账号。

## 目标
- 当 Gemini 或 Antigravity 已存在账号卡时，不再额外渲染下方重复的用量快照卡。
- 保留账号卡中的激活账号配额信息、空状态提示和 Gemini token trend。

## BDD 验收场景
1. Given Gemini 已有账号卡，When 打开用量页，Then 页面只显示账号卡，不再额外显示同一激活账号的重复 outcome 卡。
2. Given Gemini 还没有账号卡但存在错误/空状态 outcome，When 打开用量页，Then 仍显示 outcome 卡用于承载空状态或错误提示。
3. Given 非 Gemini/Antigravity provider，When 打开通用用量页，Then 维持原有 outcome 卡展示行为。

## 非目标
1. 本次不改动 Gemini 账号卡内部的信息结构。
2. 本次不调整 token trend 或导入提示展示逻辑。

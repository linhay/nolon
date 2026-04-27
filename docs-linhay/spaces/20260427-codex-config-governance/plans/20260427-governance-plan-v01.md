# Codex 配置治理计划 v01

## 目标
- 把 Codex 配置相关问题从“逐个补洞”升级成“有边界、有门禁的写入治理”。

## 已完成基线
1. `CodexConfigStore` 已统一仓内主 `config.toml` 写入口。
2. 切账号导致的旧快照回写问题已修复。
3. Codex provider 的被动 MCP repair 重写已停止。
4. Codex MCP 对官方已知字段、未知字段和未知子表的保留已补回归。
5. `ProviderMcpGridView` 的 Codex 配置初始化已改走共享 scaffold writer。
6. 已补 `scripts/tests/codex-config-governance-smoke.sh`，扫描典型 Codex 配置直写旁路。
7. Codex iCloud 同步入口已迁到设置页，账号页只保留账号与托管相关内容。

## 下一步
1. 抽离 MCP patch writer
- 从 `MCPConfigManager` 中分离 Codex TOML patch 逻辑。
- 明确输入输出：上层传递意图，下层负责 merge，不允许调用方传“整段 TOML 覆盖”。

2. 可观测性
- 给关键配置写操作加最小 debug 日志：
  - 触发模块
  - 目标文件
  - 受控片段
  - 是否为 merge 写回
- 目标是以后收到“配置被改坏”时可快速定位责任路径。

3. 回归矩阵扩充
- 增加混合场景测试：
  - 切账号 + MCP enable/disable
  - 高级配置保存 + relay restore
  - 全文编辑 + 结构化 patch
  - 用户已有手写未知 section
  - iCloud 同步入口在设置页可见、账号页不可见

## 风险
1. `MCPConfigManager` 当前职责偏重，继续叠逻辑会提高后续维护成本。
2. 如果没有旁路门禁，新的直接写入仍可能绕开治理。
3. 如果未来官方 Codex schema 扩展较快，仍需要依赖 unknown-preserving 策略兜底。

## 完成判据
1. Codex 配置生产写路径有清单、有归属、有统一入口。
2. MCP 局部写不丢未知参数的规则被测试长期锁住。
3. 新写路径出现时，能在代码评审或门禁阶段被拦下，而不是等用户反馈。

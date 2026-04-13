# Codex Gateway And Auto-Switch Runbook（2026-03-13）

## 状态更新（2026-04-10）
1. 本 runbook 已归档。
2. `gateway` 子命令与主工程内的 gateway daemon 已移除，以下 gateway 启停/排障步骤不再适用于当前仓库。
3. 当前主工程仅保留 auto-switch 相关诊断路径；如后续恢复 gateway，请以独立 SPM 仓库中的 runbook 为准。

## 适用范围
1. Codex 本地 HTTP gateway 模式的启动、停止、排障与回归。
2. Codex 非网关自动切号模式的诊断与回归。

## 前置条件
1. 已安装真实 `codex`，并且可通过 `PATH` 或 `CODEX_CLI_PATH` 发现。
2. Nolon 中已经存在至少一个 Codex 账号。
3. 本机可读写：
   - `~/.nolon/codex/auth`
   - `~/.nolon/codex/gateway`
   - `~/.nolon/codex/auto-switch`

## 快速健康检查
1. Providers 测试
```bash
swift test --package-path libs/Providers
```

2. 主工程构建
```bash
./build.sh
```

3. Codex CLI 可用性
```bash
codex --help
```

4. Gateway 状态
```bash
nolon codex gateway status --json
```

5. Auto-switch 状态
```bash
nolon codex autoswitch status
```

## Gateway 模式操作
### 启动
```bash
nolon codex gateway start --port 4319
```

### 停止
```bash
nolon codex gateway stop
```

### 查看状态
```bash
nolon codex gateway status --json
```

### 查看日志
```bash
nolon codex gateway logs --tail 100
```

### 自检
```bash
nolon codex gateway doctor
```

## Auto-switch 模式操作
### 开启
```bash
nolon codex autoswitch enable
```

### 关闭
```bash
nolon codex autoswitch disable
```

### 查看状态
```bash
nolon codex autoswitch status
```

### 自检
```bash
nolon codex autoswitch doctor
```

## 关键路径与文件
### Gateway
1. 配置：`~/.nolon/codex/gateway/config.json`
2. 状态：`~/.nolon/codex/gateway/state.json`
3. 会话：`~/.nolon/codex/gateway/sessions.json`
4. 指标：`~/.nolon/codex/gateway/metrics.json`
5. 最近错误：`~/.nolon/codex/gateway/recent-errors.jsonl`
6. 最近请求：`~/.nolon/codex/gateway/recent-requests.jsonl`
7. PID：`~/.nolon/codex/gateway/gateway.pid`
8. 日志：`~/.nolon/codex/gateway/logs/gateway.log`

### Auto-switch
1. 配置：`~/.nolon/codex/auto-switch/config.json`
2. 状态：`~/.nolon/codex/auto-switch/state.json`
3. 事件：`~/.nolon/codex/auto-switch/events.jsonl`

## 常见故障与处理
### 1. Gateway 启动失败
现象：`gateway start` 返回端口占用或启动失败。  
排查：
1. 查看 `state.json` 是否残留旧 PID。
2. 确认端口是否被其它进程占用。
3. 查看 `gateway.log` 中最后一条启动错误。

处理：
1. 停掉旧进程。
2. 删除无效 PID 文件后重试。
3. 必要时更换端口重新启动。

### 2. Gateway 已启动但请求未走网关
现象：`status` 显示 running，但请求仍直连旧上游。  
排查：
1. 检查 Codex 配置是否已 patch。
2. 检查 `state.json` 中 `configPatched` 是否为 `true`。
3. 对比 patch 前后受控字段。

处理：
1. 重新执行 `gateway stop` 后 `gateway start`。
2. 若 restore/patched 状态异常，清理 gateway 配置快照后重试。

### 3. Gateway 没有可用候选账号
现象：所有请求都直接失败。  
排查：
1. 查看 `GET /gateway/accounts` 或 `status/doctor`。
2. 检查账号是否缺少凭证。
3. 检查是否全部熔断或全部超并发。

处理：
1. 修复凭证。
2. 等待熔断冷却结束。
3. 降低筛选条件或恢复至少一个可调度账号。

### 4. Sticky 会话异常漂移
现象：同一会话频繁切换账号。  
排查：
1. 查看 `sessions.json` 是否存在该 session key。
2. 查看最近错误是否频繁触发 failover。
3. 检查请求是否稳定携带 `session_id` / `conversation_id` / `previous_response_id`。

处理：
1. 修复请求端会话锚点。
2. 检查候选账号是否频繁进入熔断。
3. 调整 sticky TTL 或 failover 策略。

### 5. 非网关自动切号没有发生
现象：当前账号余量低，但系统没有切号。  
排查：
1. 检查当前模式是否仍是 `gateway`。
2. 检查 `autoSwitchEnabled` 是否为 `true`。
3. 检查 usage 自动刷新是否真的完成。
4. 检查 `events.jsonl` 是否记录了 `cooldown` 或 `no_candidate`。

处理：
1. 关闭 gateway。
2. 开启 auto-switch。
3. 调低阈值或降低最低候选余量要求。

### 6. 非网关自动切号频繁抖动
现象：账号短时间反复切换。  
排查：
1. 查看 `cooldownMinutes` 设置。
2. 查看最近切号事件是否由同一阈值反复触发。
3. 检查多个账号 quota 是否都接近阈值。

处理：
1. 增大 cooldown。
2. 提高候选最低余量要求。
3. 只保留明显更优的候选。

## 回归清单
### 必做
1. `swift test --package-path libs/Providers`
2. `./build.sh`

### 定向
1. Gateway 启停与状态
2. Config patch / restore
3. Sticky + failover
4. 熔断恢复
5. Auto-switch 触发、cooldown、无候选分支

## 发布说明模板
1. 变更范围：
2. 模式影响：
3. 风险点：
4. 回滚策略：
5. 已执行验证：
6. 已知限制：

# Codex Runtime Runbook

## 适用范围
- Nolon 中 Codex 相关故障排查与回归验证。
- 重点覆盖 CLI 可执行解析、app-server RPC、生成文件解析与账号切换。

## 前置条件
- 已安装真实 `codex`（可执行路径可通过 `PATH` 或 `CODEX_CLI_PATH` 发现）。
- 本机可访问 `~/.codex`（或设置 `CODEX_HOME`）。

## 快速健康检查
1. CLI 可用性
```bash
codex --help
```

2. Providers 回归
```bash
swift test --package-path libs/Providers
```

3. 主工程构建验证
```bash
./build.sh
```

4. Runtime Tab 定向回归
```bash
xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' \
  -only-testing:nolonTests/CodexRuntimeTabConfigurationTests \
  -only-testing:nolonTests/CodexRuntimeTabViewModelTests \
  -only-testing:nolonTests/CodexPIDSystemLogServiceTests \
  test
```

## 常见故障与处理
1. 现象：`codex` 找不到  
原因：PATH 未包含或 `CODEX_CLI_PATH` 未设置。  
处理：设置 `CODEX_CLI_PATH=/absolute/path/to/codex` 后重试。

2. 现象：运行时账号切换失败  
原因：`accessToken` 无效/过期、`chatgptAccountId` 不匹配。  
处理：重新获取 token，重新调用 `account/login/start`，并观察 `account/updated` 通知。

3. 现象：用量或额度为空  
原因：RPC 会话不可用，或本地生成文件为空。  
处理：先验证 app-server 连通，再检查 `~/.codex/sessions/**/*.jsonl` 与 `~/.codex/history.jsonl` 是否有新数据。

4. 现象：qmd 索引未更新  
原因：未执行索引命令或 qmd 环境异常。  
处理：
```bash
qmd status
qmd update
qmd embed
```

5. 现象：Runtime Tab 显示空列表但 CLI 有进程  
原因：provider 过滤不匹配（`codex` vs `codex-xcode`）或进程命令不含预期 hint。  
处理：先用 `nolon codex runtime list --provider-id <id>` 对照，再检查 provider templateId 与 tab providerID 映射。

## 回归门禁
- 必做：
  - `swift test --package-path libs/Providers`
  - `./build.sh`
- 可选（定向）：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:<Target/TestCase> test`

## 变更发布说明模板
- 变更范围：
- 风险点：
- 回滚策略：
- 已执行验证：
- 已知限制：

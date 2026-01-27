# Nolon v0.0.2 Release Notes

## 构建与分发优化

本版本重点优化了应用的构建、签名及自动化分发流程，提升了发布效率。

- **自动化构建系统**:
  - 实现了支持 Universal (Apple Silicon & Intel) 的 DMG 打包脚本。
  - 集成了代码签名 (Code Signing) 与公证 (Notarization) 流程，确保 macOS 系统上的运行安全性。
- **配置管理**:
  - 支持通过 `.env` 文件配置构建环境变量。
  - 优化了构建产物的目录结构，自动区分 `build-arm64` 与 `build-x86_64`。
- **代码库维护**:
  - 更新了项目版本号同步逻辑，确保各处版本号的一致性。
  - 优化了 `.gitignore`，规范了对临时编译产物的忽略。

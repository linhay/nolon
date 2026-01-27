# Skill: swift-coding-standards

本 Skill 用于规范 Swift 编程风格与语法规范，避免常见的访问控制 (Access Control) 冲突与调用顺序错误。

## 触发条件
- 编写或修改 Swift 代码文件时。
- 调整基础设施层（Infrastructure）或公共模型（Models）时。

## 规则 (Do)
- **访问控制对齐**: 
    - 如果一个方法、属性或初始化项是 `public` 的，那么它引用的所有类型（包括参数类型、返回类型、属性类型）也必须至少是 `public` 的。
    - 在公共类中添加新方法时，优先检查相关类型的可见性。
- **参数顺序一致性**: 
    - 在调用视图或函数时，参数顺序必须与声明顺序完全一致。
    - 修改构造函数签名后，立即使用全局搜索功能同步更新所有调用点。
- **并发安全**: 
    - 模型结构体（Models）优先支持 `Sendable` 协议。
- **构建验证**:
    - 在完成逻辑修改后，必须运行 `/verify-build` 工作流以确保没有遗留的语法错误。

## 禁令 (Don't)
- 禁止在 `public` 接口中暴露 `internal` 级别的数据结构。
- 禁止在不确认调用点的情况下修改已有的 `public` 方法签名。

## 验证 (Validation)
- 检查是否存在 `Method cannot be declared public because its parameter uses an internal type` 编译警告。
- 检查所有构造函数调用是否能通过编译。

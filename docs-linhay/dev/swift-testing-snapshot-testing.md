# Swift Testing Snapshot Testing（macOS）

## 背景
- `nolonTests` 已接入 `pointfreeco/swift-snapshot-testing`。
- 快照测试采用 `Swift Testing`（`import Testing`），不新增 `XCTestCase`。

## 当前覆盖
- 文件：`nolonTests/ToastViewSnapshotTests.swift`
- 基线：`nolonTests/Snapshots/ToastViewSnapshotTests/*.png`
- 用例：
  - neutral style screenshot
  - success style screenshot

## 运行方式
```bash
xcodebuild test -quiet \
  -project nolon.xcodeproj \
  -scheme nolon-app \
  -destination 'platform=macOS' \
  -only-testing:nolonTests/ToastViewSnapshotTests
```

## 更新快照基线
- 当视觉变更是预期行为时，使用 SnapshotTesting 录制模式更新基线。
- 推荐在本地临时改为 `.all` 录制，再恢复 `.failed` 并提交新基线图。

## 注意事项
- 固定视图尺寸与外观（如 `.aqua`/light）可降低快照抖动。
- 快照测试依赖渲染环境，CI 和本地 Xcode/macOS 版本应尽量一致。

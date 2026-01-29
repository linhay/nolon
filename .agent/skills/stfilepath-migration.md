# Skill: stfilepath-migration

将仓库内的 `FileManager` 文件操作替换为 `STFilePath`（`STPath`/`STFile`/`STFolder`）的规则与验收清单。

## scope
- 仅适用于本仓库（Nolon）。
- 适用于所有涉及：存在性判断、目录枚举、创建目录、拷贝/移动/删除、写文件、创建 symlink 的改动。

## 触发条件
- 用户明确要求“用 STFilePath 替换/不要 FileManager”。
- 新增或修改任何文件系统相关逻辑（Infrastructure / ViewModel / View）。

## do
- **优先使用 STFilePath 类型：**
  - 路径存在：`STPath(path).isExists` / `STFile(urlOrPath).isExists` / `STFolder(urlOrPath).isExists`
  - 目录创建：`STFolder(path).createIfNotExists()`
  - 目录枚举：`try STFolder(path).files()` / `folders()` / `subFilePaths()`
  - 写文件（覆盖）：`try STFile(pathOrURL).overlay(with: dataOrString)`
  - 拷贝/移动：`try STPath(src).copy(to: STPath(dst), isOverlay: true)` / `move(to:isOverlay:)`
  - symlink：`try STPath(link).createSymbolicLink(to: STPath(target))`
- **删除时处理 broken symlink：**
  - `STPathProtocol.delete()` 内部依赖 `FileManager.fileExists`，对“断链 symlink”会跳过；
  - 在需要“无论是否断链都删掉”的场景，统一使用 `deleteIncludingBrokenSymlink()`（仓库内扩展）。
- **Home 目录：**
  - 仅为获取 `String`/`URL` 时，优先 `NSHomeDirectory()` 或 `URL(fileURLWithPath: NSHomeDirectory())`；
  - 或使用 `STFolder("~")` 构造相对路径（让 `~` 展开由库处理）。

## dont
- 不要新写 `FileManager.default.fileExists/removeItem/copyItem/moveItem/contentsOfDirectory/createDirectory` 这类调用（除非是系统 API 限制只能用 FileManager 的场景，并在同一处注明原因）。
- 不要用 `fileExists` 作为“是否是 symlink/是否断链”的依据。

## exceptions
- 仅当第三方 API / 系统 API 只接受 `FileManager` 或强依赖其语义时允许保留；保留时必须局部封装，避免扩散到业务层。

## validation
- 全仓 `rg -n "\\bFileManager\\b" nolon`：只允许剩余注释/兼容说明（不应再出现业务逻辑调用）。
- 运行 `/verify-build`（`./build.sh`）确保编译通过。


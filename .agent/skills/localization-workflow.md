# Skill: localization-workflow

本 Skill 用于规范 `nolon` 项目中的本地化（Localization）自动化处理流程，确保 `Localizable.xcstrings` 文件的完整性与格式准确。

## 触发条件
- 修改了 UI 文字或 `NSLocalizedString` 的 Key/Value 时。
- 准备提交 PR 或合并分支前。
- 发现界面中存在未翻译的英文或 Key 名时。

## 执行流程 (Do)
1. **提取缺失项**: 切换至 `scripts/` 目录，并执行 `python3 extract_missing_translations.py`。
2. **刷新待翻译列表**: 该脚本会生成或更新 `scripts/missing_translations.json`。
3. **编写翻译内容**: 
    - 修改 `scripts/translated_items.json`。
    - 将 `missing_translations.json` 中的新 Key 及其对应的中文翻译填入该文件。
4. **导入本地化字符串**: 执行 `python3 import_translations.py`，将 `translated_items.json` 中的内容同步回 `nolon/Localizable.xcstrings`。
5. **标记完成**: 该脚本会自动将导入项的状态设为 `translated`。

## 禁令 (Don't)
- **禁止手动编辑**: 严禁直接通过文本编辑器修改 `Localizable.xcstrings` 中的 JSON，以防止 JSON 语法错误或破坏 Xcode 的索引。
- **禁止硬编码**: 禁止在 View 中直接使用中文硬编码，必须包裹在 `NSLocalizedString` 中，并配以清晰的 `comment`。

## 验证 (Validation)
- 运行提取脚本后，产生的 `missing_translations.json` 应为空，或不再包含你刚刚修改的 Key。
- 在 Xcode 中打开 `Localizable.xcstrings` 检查 zh-Hans 列是否已填入正确文案。

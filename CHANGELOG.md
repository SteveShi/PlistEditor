# Changelog

## [1.1.0] - 2026-06-10

<div lang="en">

### Added
- Added built-in structure definitions for `*.entitlements`, `LaunchServices.plist`, and `.GlobalPreferences.plist`.
- Supported copying, cutting, and pasting nodes across documents via system clipboard.
- Added "Sort Keys" command (Cmd+Shift+S) to sort dictionary keys alphabetically.
- Extended "View As" with UInt16/UInt32/Float32 Little/Big Endian byte-order presentations for Data.
- Added "View By Subkey" feature in the toolbar to temporarily sort outline nodes by a subkey value.
- Implemented Preferences Browser (Cmd+Shift+B) to easily find and open plist files in macOS preference directories.
- Added basic AppleScript support, exposing the `format` property of `document` to AppleScript (XML, binary, or JSON).

</div>

### Chinese

---

<div lang="zh">

### 新增功能
- 针对 `*.entitlements`、`LaunchServices.plist` 及 `.GlobalPreferences.plist` 新增了内置结构定义，支持键补全与描述提示。
- 支持通过系统剪贴板跨文档复制、剪切和粘贴节点（快捷键 Cmd+C / Cmd+X / Cmd+V）。
- 新增“排序键”命令（快捷键 Cmd+Shift+S），可对字典键按字母序重新排序。
- 扩展了“查看为”格式化器，新增 Data 的 UInt16/UInt32/Float32 大小端字节序展示。
- 新增“按子键排序”工具栏功能，可在大纲中临时按照子键的值对节点进行排序显示。
- 实现了“偏好设置浏览器”独立窗口（快捷键 Cmd+Shift+B），可快速查找并双击打开 macOS 偏好设置目录下的 plist 文件。
- 添加了基础 AppleScript 脚本支持，支持通过 AppleScript 读写 `document` 的 `format` 格式（XML、二进制或 JSON）。

</div>

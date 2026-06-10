# Changelog

## [1.1.2] - 2026-06-10

<div lang="en">

### Added
- Added context menus for outline view items with actions: Set to Default Value, Copy As (XML/Binary/JSON), Edit Value, and Sort Values.
- Associated the app with Property List, JSON, and XML file types to show up in macOS "Open With" menu.

</div>

### Chinese

---

<div lang="zh">

### 新增功能
- 为大纲视图中的节点项新增了右键上下文菜单，支持“设为默认值”、“复制为 (XML/Binary/JSON)”、“编辑值”和“排序值”等操作。
- 关联了属性列表 (Property List)、JSON 和 XML 文件类型，以支持在 macOS“打开方式”菜单中打开。

</div>

## [1.1.1] - 2026-06-10

<div lang="en">

### Fixed
- Fixed a startup crash on macOS 15+ (Sequoia) caused by Swift runtime class name reflection and custom `NSDocumentController` subclass pointer authentication (PAC) mismatch.

</div>

### Chinese

---

<div lang="zh">

### 修复
- 修复了在 macOS 15+ (Sequoia) 上由于 Swift 运行时类名反射以及自定义 `NSDocumentController` 子类导致指针认证 (PAC) 不匹配而引发的启动崩溃问题。

</div>

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

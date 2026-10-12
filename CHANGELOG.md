# Changelog

## [1.1.6] - 2026-10-12

<div lang="en">

### Fixed
- Fixed an issue where the Format popup button in the toolbar compressed into an empty pill displaying only arrows without text by replacing the toolbar picker with a native Menu.
- Cleaned up redundant duplicate chevron arrows on the Format menu button, keeping a single native dropdown indicator.
- Fixed an issue where edited documents did not show the macOS standard dark dirty-dot indicator inside the window close button (red dot) upon modifications.
- Improved the "View As" toolbar item by adding the standard `eye` system symbol and tooltip, clearly identifying its purpose even when disabled for unsupported node types.

</div>

### Chinese

---

<div lang="zh">

### 修复
- 修复了工具栏中文件格式切换器（Format Popup）文本被系统挤压、显示为空白胶囊按钮的问题（使用原生 Menu 彻底替代 Picker，根治 macOS 工具栏空间受限时的文字剥离问题）。
- 修复了格式切换按钮右侧多余出现两个箭头图标的问题，精简为原生单个下拉指示器。
- 修复了编辑修改文件时窗口关闭按钮（红点）未正常显示 macOS 经典深色“已编辑”圆点指示器（dirty dot）的问题。
- 优化了工具栏“查看为”（View As）按钮，增加标准眼睛图标及悬停提示，便于在未选中对应节点类型时识别其功能。

</div>

## [1.1.5] - 2026-09-20

<div lang="en">

### Fixed
- Fixed an issue where saving an edited document triggered an unintended external file reload, causing all expanded outline items to collapse and requiring a second Cmd+S to persist changes.
- Fixed an issue where edited documents did not show the macOS standard dark-dot/shadow edited indicator in the window close button.

</div>

### Chinese

---

<div lang="zh">

### 修复
- 修复了保存修改后的 plist 文件时触发自身写盘误重载、导致所有展开的大纲项被收起且需保存两次的问题。
- 修复了已编辑文件在窗口关闭按钮上未显示 macOS 默认淡灰色阴影（已编辑状态小黑点指示器）的问题。

</div>

## [1.1.4] - 2026-07-23

<div lang="en">

### Fixed
- Fixed Sparkle automatic update initialization error by embedding `SUFeedURL`, `SUPublicEDKey`, and Sparkle update settings directly into `Info.plist`.
- Implemented `feedURLString(for:)` in `SparkleUpdaterDelegate` for reliable update feed resolution.

</div>

### Chinese

---

<div lang="zh">

### 修复
- 修复了 Sparkle 自动更新初始化报错“未配置 SUFeedURL”的问题，将 `SUFeedURL`、`SUPublicEDKey` 及自动更新相关键补全至 `Info.plist`。
- 在 `SparkleUpdaterDelegate` 中实现了 `feedURLString(for:)` 委托方法，提供更可靠的 Appcast Feed 解析保障。

</div>

## [1.1.3] - 2026-07-23

<div lang="en">

### Refactored
- Deduplicated byte-decoding loops across integer and floating-point presentations (`ValueFormatter`).
- Consolidated selection helper logic and container traversal in outline view operations (`ContentView`).
- Cleaned up unreferenced legacy files.

</div>

### Chinese

---

<div lang="zh">

### 重构优化
- 重构并精简了 Data 数字/浮点数字节序转换的重复编解码逻辑 (`ValueFormatter`)。
- 提炼了编辑操作与上下文菜单中的节点选择和容器遍历辅助逻辑 (`ContentView`)。
- 清理了仓库根目录下的非必要残余文件。

</div>

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

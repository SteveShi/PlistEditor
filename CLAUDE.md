# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

PlistEditor 是 **PlistEdit Pro** 的 macOS 复刻：上方 `键/类型/值` 三列大纲树，下方与之同步的语法高亮源码面板。SwiftUI 文档型应用 + Swift 6。

## 构建与运行 / Commands

工程文件由 **XcodeGen** 从 `project.yml` 生成，`PlistEditor.xcodeproj` 不入库（见 `.gitignore`）。**增删/重命名源文件后必须重新生成工程**：

```bash
xcodegen generate
xcodebuild -project PlistEditor.xcodeproj -scheme PlistEditor -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

运行已构建产物：`open <DerivedData>/.../PlistEditor.app`。打开样例文件冒烟测试：`open -a <app> /path/Info.plist`（文件名为 `Info.plist` 会触发结构定义匹配）。

目前**没有测试 target**。改动后以 `xcodebuild build` 通过为基本验证；UI 变更建议构建后启动应用截图确认。

## 并发设计（最重要，勿回退）

打开磁盘文件时，SwiftUI 在**后台队列**调用 `ReferenceFileDocument.init(configuration:)`。因此 **`PlistDocument` 与整个模型/序列化层必须是 `nonisolated`**：

- 若把 `PlistDocument` 或 `PlistNode` 标 `@MainActor`，运行时 `_checkExpectedExecutor` 会在**打开文件**时陷阱崩溃（新建文档不崩，极具迷惑性）。`@preconcurrency` 只压编译告警，挡不住运行时崩溃。
- `PlistNode` 标 `@unchecked Sendable`（后台构建、之后仅主线程使用，一次性 handoff）。
- `UndoManager.registerUndo` 自身是 `@MainActor`，所以**只有**用到它的方法（`PlistDocument.setRoot/setFormat/syncOutlineFromText` 及 `PlistDocument+Editing`/`+Move` 整个扩展）单独标 `@MainActor`，其撤销闭包内用 `MainActor.assumeIsolated { ... }`。
- `nonisolated(unsafe)` 不能与 `@Published` 组合（编译失败）。

## 架构要点（需跨文件理解的部分）

- **单一数据源**：`PlistNode`（`@Observable` 引用树）是大纲与源码的唯一真相源。所有结构/值变更都经 `PlistDocument`（`Document/PlistDocument+Editing.swift`、`+Move.swift`）执行并向 `UndoManager` 注册逆操作——这同时负责把文档标记为已修改，**不要绕过它直接改树**。

- **类型系统**：七种 `PlistType`，整数与浮点都归为 `Number`（`PlistNode.Kind` 内部用 `.integer`/`.real` 区分，序列化时还原）。字典按键字母序显示（与 plist 序列化一致），数组保序。

- **大纲渲染**：SwiftUI `Table` 不支持任意层级递归，故 `PlistOutlineView` 把当前可见节点**扁平化**成一维数组喂给 `Table`，展开箭头与缩进在 `KeyCell` 里**自绘**（`expanded: Set<UUID>` 控制）。拖拽用 `DraggedNodeID`（`Transferable`）+ `.dropDestination`。

- **源码同步是非对称的**（`PlistDocument` + `Views/Source/`）：大纲→文本可自动（`autoSyncText`）或手动（Sync text）；文本→大纲**永远手动**（Sync outline），解析失败给含行号的报错。

- **序列化**（`Serialization/PlistSerializer.swift`）：XML/二进制/OpenStep 走 `PropertyListSerialization`，JSON 走 `JSONSerialization`；OpenStep **只读**，加载时转成 XML 编辑。节点树 ↔ Foundation 对象互转时，布尔用 `kCFBoolean*`、整/浮点用 `CFNumberIsFloatType` 区分。

- **AppKit 桥接**：源码面板（`SourceTextView`）和带原生补全的键输入框（`CompletingTextField`）都用 `NSViewRepresentable` 包 AppKit 控件，因为 SwiftUI 缺少富文本编辑与补全。

- **View As**：每节点的显示格式存在 `PlistDocument.viewAs[node.id]`（display state，不持久化），值单元格据此格式化/解析（`Model/ValueFormatter.swift`）。

- **结构定义**：`Resources/StructureDefinitions/*.json` 被 XcodeGen 扁平化进 bundle 根，`StructureDefinitionStore` 枚举 bundle 内 `.json` 加载，按文件名匹配激活，提供键补全与描述。

## 本地化策略（项目特定，务必遵守）

- **只本地化界面外壳**（列头、工具栏、菜单、同步控件、对话框）——用 `LocalizedStringKey` 字面量，翻译写在 `Resources/Localizable.xcstrings`（en + zh-Hans）。
- **编辑器内的数据术语保持英文**——类型名（`Dictionary` 等）、`Root`、`Item N`、`N key/value pairs` 值摘要、`Format`/`View As` 的枚举值——一律用 `Text(verbatim:)` 固定英文，**不要**加进字符串目录。理由：与 Xcode / PlistEdit Pro 一致，技术术语翻译生硬。

## 功能现状 / Feature status

**已实现**：新建/打开/保存/自动保存/撤销；任意层级三列大纲；七种类型 + 原地改类型（尽力转换原值）；按类型适配的值编辑器；字典键内联编辑、数组 `Item N` 索引；新建同级/子级/复制/删除；XML/二进制/JSON 读写（可读 OpenStep）；源码面板语法高亮 + 双向同步；拖拽重排/重新归属；多选批量删/复制；查找替换（Cmd+F）；View As 格式化器（Number/Data/Data 字节序 LE/BE 变体）；结构定义键自动补全与描述（内置 Info.plist / Entitlements / LaunchServices / GlobalPreferences）；设置窗口（Cmd+,，General/Display/Browsing 三标签页）；界面语言切换（跟随系统/英文/简体中文，重启生效）；跨文档复制粘贴（支持保留字典键包装的剪贴板操作）；字典键快速排序（Sort Keys, Cmd+Shift+S）；按子键排序（View By Subkey）；偏好设置浏览器窗口（Preferences Browser, Cmd+Shift+B，支持多路径异步浅扫描与双击打开）；基础 AppleScript 读写支持（可获取与修改文档 format）。

设置（`Sources/Settings/`）：`AppSettings` 以 **UserDefaults** 持久化（计算属性 + `objectWillChange`，无加载步骤）。视图用 `@MainActor` 单例 `AppSettings.shared`；**后台读取**（文件读写时的 JSON 缩进、默认格式、排序选项）走 `nonisolated static` 访问器直读 `UserDefaults`（线程安全）。已接线生效：默认格式、默认类型、展开方式、大纲/文本字体、XML 着色开关+颜色、JSON 显示/保存缩进、记忆格式化器、自动保存、文件变更提醒、激活时动作（`applicationShouldOpenUntitledFile`）、排序选项（大小写敏感/数字排序，影响字典键序）、回车编辑下一行、浏览器过滤扩展名（`browsingExtensions` 过滤偏好浏览器显示）。语言切换写 `AppleLanguages` + 提示重启（`LanguageController`）；新增语言只需在 `AppLanguage.all` 加一项 + 补 xcstrings/lproj。浏览扩展名暂仅持久化，待偏好浏览器功能落地。

自动保存（`AutosaveDocumentController`）：`NSDocumentController` 子类，覆盖 `autosavingDelay`，根据 `enableAutosaving` 设置动态返回系统默认值或 0（禁用）。通过 `AppDelegate.applicationWillFinishLaunching` 在 `NSDocumentController.shared` 之前安装。

文件变更提醒（`FileWatcher` + `ContentView`）：`DispatchSource.makeFileSystemObjectSource` 监控 `.write/.rename/.delete`，原子保存（rename）后自动重新绑定。检测到内容变更时，`askToRevert == true` 弹 Alert 询问用户，`askToRevert == false` 静默重载。重载使用 `PlistSerializer.parse` + `document.setRoot` 走撤销栈。

**路线图（剩余规划）**：View As 别名/书签；AppleScript 控制节点树（留待后续版本评估）。

## 与 PlistEdit Pro 框架的技术映射

PlistEdit Pro 随包含一组私有/第三方框架，本项目以原生方案替代：

| PlistEdit Pro 框架 | 用途 | 本项目对应 |
| --- | --- | --- |
| `BWFoundation` / `BWAppKit` / `BWViewControllers` | 作者私有 Foundation/AppKit 扩展与 VC 基建 | 原生 SwiftUI + AppKit 桥接 |
| `BWAppleEvents` | AppleScript / Apple Events | 路线图：`NSApplicationDelegate` + 脚本字典 |
| `BWFileWatching` | 磁盘文件外部变更监听 / revert | `NSDocument` 机制或 `FSEvents`（路线图） |
| `BWRegistration` | 许可证 / 注册校验 | 不需要（开源，无授权层） |
| `SBJson` | 早期 JSON 解析 | Foundation `JSONSerialization` |
| `Sentry` | 崩溃 / 错误上报 | 可选，预留接入点 |
| `Sparkle` | 应用内自动更新 | 预留接入点；接入时经 SPM 加 Sparkle 2.x + `SPUStandardUpdaterController` + `SUFeedURL`/`SUPublicEDKey`，对接既有 Sparkle 发布工作流 |

## 分发

通过 Homebrew tap 分发：`github.com/SteveShi/homebrew-tap` 的 `Casks/plisteditor.rb`（cask 指向 `github.com/SteveShi/PlistEditor` 的 release DMG）。发版时更新 cask 的 `version` 与 `sha256`。

面向用户的安装/功能说明见 `README.md`（英文）与 `README.zh-CN.md`（中文）。

License: Mozilla Public License 2.0 (MPL-2.0). Copyright © 2026 轩楝 (Steve Shi).

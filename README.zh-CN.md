<div align="center">

# PlistEditor

[English](README.md) · **简体中文**

参照 **PlistEdit Pro** 的原生 macOS 属性列表编辑器——上方是 `键 / 类型 / 值` 三列大纲树，下方是与之同步的语法高亮源码视图。使用 SwiftUI 与 Swift 6 构建。

</div>

## 功能

- **双重表示**——既能以可折叠的 `键 / 类型 / 值` 大纲编辑，也能直接编辑源码文本，两者保持同步。
- **七种属性列表类型**——`Array`、`Dictionary`、`Boolean`、`Data`、`Date`、`Number`、`String`。可原地改类型，并尽力转换原值。
- **按类型适配的值编辑器**——文本框、布尔 `YES/NO` 弹出、日期、Data 十六进制。
- **结构编辑**——工具栏 / `操作` 菜单 / 快捷键完成新建同级、新建子级、复制、删除；支持多选。
- **拖拽**——重排与重新归属节点（含循环检测），完全可撤销。
- **多格式**——读写 XML、二进制、JSON（可读取 OpenStep/旧式 ASCII）；通过 `Format` 弹出切换。
- **源码同步面板**——XML/JSON 语法高亮，`自动同步文本`、手动 `同步文本`（大纲→文本）与 `同步大纲`（文本→大纲，解析错误含行号）。
- **查找替换**——`⌘F` 搜索键与值、导航匹配项、替换单个或全部。
- **View As**——将数字重解释为十进制 / Hex / OSType / 存储大小 / `HH:MM:SS`，将数据重解释为 Hex / UTF-8 / ASCII / Base64。
- **结构定义**——对已知文件提供原生键自动补全与描述（内置 Info.plist 定义，按文件名匹配）。
- **偏好设置**——设置窗口（⌘,），含通用 / 显示 / 浏览三个标签页：默认格式与类型、打开时展开方式、大纲/文本字体、XML 标签颜色、JSON 格式等。
- **本地化界面**——中英双语界面并支持应用内语言切换；数据术语（类型名、`Root`、`Item N`、值摘要）保持英文，与 Xcode / PlistEdit Pro 一致。

## 安装

通过 [Homebrew](https://brew.sh)：

```bash
brew tap SteveShi/tap
brew install --cask plisteditor
```

## 从源码构建

需要 macOS 14+、Xcode 16+（Swift 6）与 [XcodeGen](https://github.com/yonbergman/xcodegen)。Xcode 工程由 `project.yml` 生成，不纳入版本库。

```bash
brew install xcodegen
xcodegen generate
open PlistEditor.xcodeproj
# 或命令行编译：
xcodebuild -project PlistEditor.xcodeproj -scheme PlistEditor -configuration Debug build
```

## 与 PlistEdit Pro 的对照

PlistEdit Pro 随包内含一组私有与第三方框架，本项目以原生方案对应替代：

| PlistEdit Pro 框架 | 用途 | 本项目对应 |
| --- | --- | --- |
| `BWFoundation` / `BWAppKit` / `BWViewControllers` | 私有 Foundation/AppKit 扩展与视图控制器基建 | 原生 SwiftUI + 少量 AppKit 桥接 |
| `BWAppleEvents` | AppleScript / Apple Events 自动化 | 路线图（`NSApplicationDelegate` + 脚本字典） |
| `BWFileWatching` | 监听磁盘文件外部变更 / revert | `NSDocument` 机制或 `FSEvents`（路线图） |
| `BWRegistration` | 许可证 / 注册 | 不需要（开源） |
| `SBJson` | 早期 JSON 解析 | Foundation `JSONSerialization` |
| `Sentry` | 崩溃 / 错误上报 | 可选，预留接入点 |
| `Sparkle` | 应用内自动更新 | 预留接入点（SPM `Sparkle` 2.x） |

## 路线图

更多内置结构定义与 Xcode 插件格式导入 · `defaults` / 偏好设置浏览器（经 `CFPreferences` 写入） · 跨文档复制粘贴 · OpenStep 写出 · AppleScript 与 `pledit` 命令行工具 · View As 的别名/书签/字节序变体。

## 许可

Copyright © 2026 轩楝 (Steve Shi).

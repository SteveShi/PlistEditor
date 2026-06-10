<div align="center">

# PlistEditor

**English** · [简体中文](README.zh-CN.md)

A native macOS property-list editor modeled on **PlistEdit Pro** — a three-column (`Key / Class / Value`) outline tree on top, with a synchronized, syntax-highlighted source view below. Built with SwiftUI and Swift 6.

</div>

## Features

- **Dual representation** — edit as a collapsible `Key / Class / Value` outline *and* as raw source text, kept in sync.
- **All seven plist classes** — `Array`, `Dictionary`, `Boolean`, `Data`, `Date`, `Number`, `String`. Change a node's class in place; the existing value is converted best-effort.
- **Per-type value editors** — text fields, a `YES/NO` popup for booleans, dates, and hex for data.
- **Structural editing** — add sibling / add child / duplicate / delete from the toolbar, the Operations menu, or keyboard shortcuts; full multi-selection.
- **Drag and drop** — reorder and re-parent nodes (with cycle protection), fully undoable.
- **Multiple formats** — read & write XML, Binary, and JSON (reads OpenStep/old-style ASCII); switch via the Format popup.
- **Synced source pane** — XML/JSON syntax highlighting, `Automatically sync text`, manual `Sync text` (outline → text) and `Sync outline` (text → outline) with line-numbered parse errors.
- **Find & Replace** — `⌘F` to search keys and values, navigate matches, and replace one or all.
- **View As** — reinterpret numbers (Decimal / Hex / OSType / Storage Size / `HH:MM:SS`) and data (Hex / UTF-8 / ASCII / Base64).
- **Structure definitions** — native key autocompletion and descriptions for known files (bundled Info.plist definition, matched by file name).
- **Preferences** — a Settings window (⌘,) with General / Display / Browsing tabs: default format & class, expand-on-open, outline/text fonts, XML tag color, JSON formatting, and more.
- **Localized UI** — English and 简体中文 interface with an in-app language switch; data terms (type names, `Root`, `Item N`, value summaries) stay in English, matching Xcode / PlistEdit Pro.

## Install

Via [Homebrew](https://brew.sh):

```bash
brew tap SteveShi/tap
brew install --cask plisteditor
```

## Build from source

Requires macOS 14+, Xcode 16+ (Swift 6), and [XcodeGen](https://github.com/yonbergman/xcodegen). The Xcode project is generated from `project.yml` and is not checked in.

```bash
brew install xcodegen
xcodegen generate
open PlistEditor.xcodeproj
# or from the command line:
xcodebuild -project PlistEditor.xcodeproj -scheme PlistEditor -configuration Debug build
```

## How it compares to PlistEdit Pro

PlistEdit Pro bundles a set of private and third-party frameworks; this project replaces each with a native equivalent:

| PlistEdit Pro framework | Purpose | Replacement here |
| --- | --- | --- |
| `BWFoundation` / `BWAppKit` / `BWViewControllers` | Private Foundation/AppKit extensions and view-controller infrastructure | Native SwiftUI + small AppKit bridges |
| `BWAppleEvents` | AppleScript / Apple Events automation | Roadmap (`NSApplicationDelegate` + scripting dictionary) |
| `BWFileWatching` | Watch the file for external changes / revert | `NSDocument` mechanics or `FSEvents` (roadmap) |
| `BWRegistration` | License / registration | Not needed (open source) |
| `SBJson` | Early JSON parsing | Foundation `JSONSerialization` |
| `Sentry` | Crash / error reporting | Optional, integration point reserved |
| `Sparkle` | In-app auto-update | Integration point reserved (SPM `Sparkle` 2.x) |

## Roadmap

More bundled structure definitions and Xcode-plugin import · a `defaults` / preferences browser (writing through `CFPreferences`) · cross-document copy/paste · OpenStep writing · AppleScript and a `pledit` CLI · alias/bookmark/endian `View As` variants.

## License

Copyright © 2026 轩楝 (Steve Shi).

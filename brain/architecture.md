---
slug: architecture
title: System architecture
role: system architecture
updated: "2026-08-21T06:38:35"
---

# System architecture

```mermaid
graph TD
    App[PlistEditor App] --> Tree[Hierarchical Tree Node Model]
    Tree --> Serializer[PropertyListSerialization & XML Formatter]
    App --> Views[SwiftUI TreeView & Raw XML Inspector]
```

---
title: Welcome to Markdown Reader
author: Haumea Labs
version: 1.0
---

# Welcome to Markdown Reader

A **native** Markdown viewer for macOS, written in *SwiftUI*. No web view, no
Electron — every heading, list and table you see below is a real AppKit view.

## Reading

Open any `.md` file and it renders straight away. Use ⌘1, ⌘2 and ⌘3 to move
between the rendered view, the source and the split view.

- Adjustable typeface, text size and column width
- A filterable outline in the sidebar
- Internal links such as [Tasks](#tasks) jump to the section
- Links to sibling files open in a new window
- Autolinks like https://developer.apple.com/swiftui work out of the box

> [!NOTE]
> GitHub-style callouts are recognised: `NOTE`, `TIP`, `IMPORTANT`,
> `WARNING` and `CAUTION`.

## Tasks

Checkboxes are interactive — clicking one writes the change back to the file.

- [x] Block parser
- [x] Native SwiftUI rendering
- [x] Syntax highlighting
- [ ] Scroll sync in split view
- [ ] Presentation mode

## Code

Fenced blocks are highlighted for about thirty languages, and a copy button
appears when you hover over them.

```swift
struct MarkdownPreview: View {
    let document: MDDocument      // parsed blocks
    let theme: MarkdownTheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.blockSpacing) {
                ForEach(document.blocks) { block in
                    BlockView(block: block, context: context)
                }
            }
        }
    }
}
```

```bash
# Build the app bundle and install it
./Scripts/build_app.sh --install
```

## Tables

| Feature | Shortcut | Status |
|:--------|:--------:|-------:|
| Rendered view | ⌘1 | Done |
| Source code | ⌘2 | Done |
| Split view | ⌘3 | Done |
| Outline | ⌃⌘S | Done |
| Export as HTML | — | Done |

## Editing

The source view is a real text editor: line numbers, Markdown highlighting and
find (⌘F). Smart quotes and dash substitution are switched off, because they
quietly corrupt Markdown files.

> Save with ⌘S. The document goes through the system's own document machinery,
> so Versions and Revert To work as usual.

---

Made with SwiftUI · [Read the source](https://example.com)

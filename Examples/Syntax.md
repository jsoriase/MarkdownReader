# Syntax reference

A short tour of everything Markdown Reader knows how to render.

## Text

**Bold**, *italic*, ***both***, ~~strikethrough~~, `inline code`, and
[links](https://developer.apple.com). Bare URLs such as https://swift.org are
turned into links too, and reference links like [the docs][docs] work.

[docs]: https://developer.apple.com/documentation/swiftui

## Code

```swift
extension MarkdownParser {
    /// Turns a fenced block into a code node.
    static func fence(_ line: String) -> Fence? {
        guard indent(line) < 4 else { return nil }
        let body = Substring(line).drop { $0 == " " }
        guard let first = body.first, first == "`" || first == "~" else { return nil }
        return Fence(char: first, length: body.prefix { $0 == first }.count)
    }
}
```

```python
def word_count(text: str) -> int:
    """Words, roughly."""
    return len([w for w in text.split() if w])
```

## Tables

| Element | Syntax | Rendered as |
|:--------|:-------|:------------|
| Heading | `# Title` | A styled heading |
| List | `- item` | A bulleted list |
| Task | `- [x] item` | A checkbox you can click |
| Table | `\| a \| b \|` | This table |

## Lists

1. Ordered items keep their numbering
2. And can nest
   - Mixed with bullets
   - Up to any depth
3. Back to the top level

- [x] Task lists are written back to the file
- [ ] Unchecked items stay unchecked

## Quotes and callouts

> A plain quote, with **emphasis** and `code` inside.

> [!TIP]
> Callouts come from GitHub: NOTE, TIP, IMPORTANT, WARNING and CAUTION.

> [!WARNING]
> Anything else in the brackets is left as ordinary text.

## Other blocks

Thematic breaks, images and YAML front matter are supported as well.

---

    Indented code blocks work too,
    without a language hint.

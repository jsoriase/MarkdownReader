import SwiftUI

/// Everything the block views need in order to draw themselves.
struct RenderContext {
    var theme: MarkdownTheme
    var links: [String: String] = [:]
    var baseURL: URL?
    var onToggleTask: ((Int, Bool) -> Void)?

    func inline(_ markdown: String, font: Font? = nil, color: Color? = nil) -> AttributedString {
        InlineRenderer.render(markdown,
                              style: theme.inlineStyle(font: font ?? theme.body, foreground: color),
                              links: links)
    }
}

struct BlockView: View {
    let block: MDBlock
    let context: RenderContext
    var level: Int = 0

    private var theme: MarkdownTheme { context.theme }

    var body: some View {
        switch block {
        case .heading(let heading):
            HeadingView(heading: heading, context: context)

        case .paragraph(_, let markdown, _):
            Text(context.inline(markdown))
                .lineSpacing(theme.lineSpacing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .code(let code):
            CodeBlockView(code: code, theme: theme)

        case .quote(_, let blocks):
            QuoteView(blocks: blocks, context: context, level: level)

        case .list(let list):
            ListBlockView(list: list, context: context, level: level)

        case .table(let table):
            TableView(table: table, context: context)

        case .rule:
            Divider()
                .padding(.vertical, theme.blockSpacing * 0.4)

        case .image(let image):
            MDImageView(image: image, context: context)

        case .html(_, _, let text):
            if !text.isEmpty {
                Text(context.inline(text, color: .secondary))
                    .lineSpacing(theme.lineSpacing)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .frontMatter(_, let pairs):
            FrontMatterView(pairs: pairs, theme: theme)
        }
    }
}

// MARK: - Headings

struct HeadingView: View {
    let heading: MDHeading
    let context: RenderContext

    var body: some View {
        let theme = context.theme
        VStack(alignment: .leading, spacing: theme.baseSize * 0.3) {
            Text(context.inline(heading.markdown,
                                font: theme.headingFont(heading.level),
                                color: heading.level >= 6 ? .secondary : nil))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if heading.level <= 2 {
                Divider().opacity(0.6)
            }
        }
        .padding(.top, heading.level == 1 ? theme.baseSize * 0.6 : (heading.level == 2 ? theme.baseSize * 0.5 : theme.baseSize * 0.25))
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(heading.id)
    }
}

// MARK: - Code

struct CodeBlockView: View {
    let code: MDCode
    let theme: MarkdownTheme

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(CodeHighlighter.highlight(code.code,
                                               language: code.language,
                                               font: theme.codeBlockFont,
                                               scheme: scheme))
                    .textSelection(.enabled)
                    .lineSpacing(theme.baseSize * 0.22)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.codeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.codeBorder, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if let name = CodeHighlighter.displayName(for: code.language) {
                    Text(name)
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                }
                if hovering || copied {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code.code, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                    .help("Copy code")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .onHover { hovering = $0 }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quotes and callouts

struct QuoteView: View {
    let blocks: [MDBlock]
    let context: RenderContext
    let level: Int

    private struct Callout {
        let kind: String
        let title: String
        let symbol: String
        let color: Color
    }

    private static let callouts: [String: (String, String, Color)] = [
        "note": ("Note", "info.circle.fill", .blue),
        "tip": ("Tip", "lightbulb.fill", .green),
        "important": ("Important", "exclamationmark.circle.fill", .purple),
        "warning": ("Warning", "exclamationmark.triangle.fill", .orange),
        "caution": ("Caution", "xmark.octagon.fill", .red)
    ]

    private var parsed: (Callout?, [MDBlock]) {
        guard case .paragraph(let id, let markdown, let line) = blocks.first,
              let match = markdown.range(of: "^\\[!([A-Za-z]+)\\]\\s*", options: .regularExpression)
        else { return (nil, blocks) }
        let kind = markdown[match]
            .trimmingCharacters(in: CharacterSet(charactersIn: "[!] \n"))
            .lowercased()
        guard let info = Self.callouts[kind] else { return (nil, blocks) }
        var rest = blocks
        let remainder = String(markdown[match.upperBound...])
        if remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rest.removeFirst()
        } else {
            rest[0] = .paragraph(id: id, markdown: remainder, line: line)
        }
        return (Callout(kind: kind, title: info.0, symbol: info.1, color: info.2), rest)
    }

    var body: some View {
        let theme = context.theme
        let (callout, content) = parsed

        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(callout?.color.opacity(0.65) ?? Color.secondary.opacity(0.35))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: theme.blockSpacing * 0.55) {
                if let callout {
                    Label(String(localized: String.LocalizationValue(callout.title)), systemImage: callout.symbol)
                        .font(.system(size: theme.baseSize * 0.88, weight: .semibold))
                        .foregroundStyle(callout.color)
                }
                ForEach(content) { block in
                    BlockView(block: block, context: context, level: level + 1)
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(callout == nil ? Color.secondary : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lists

struct ListBlockView: View {
    let list: MDList
    let context: RenderContext
    let level: Int

    private static let bullets = ["•", "◦", "▪", "‣"]

    var body: some View {
        let theme = context.theme
        VStack(alignment: .leading, spacing: list.tight ? theme.tightSpacing : theme.blockSpacing * 0.6) {
            ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    marker(for: item, index: index, theme: theme)
                        .frame(minWidth: list.ordered ? theme.baseSize * 1.5 : theme.baseSize * 0.7,
                               alignment: .trailing)
                    VStack(alignment: .leading, spacing: theme.blockSpacing * 0.5) {
                        ForEach(item.blocks) { block in
                            BlockView(block: block, context: context, level: level + 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func marker(for item: MDListItem, index: Int, theme: MarkdownTheme) -> some View {
        if let checked = item.checked {
            Button {
                if let line = item.checkboxLine { context.onToggleTask?(line, !checked) }
            } label: {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: theme.baseSize * 0.95))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(context.onToggleTask == nil || item.checkboxLine == nil)
            .help("Toggle task")
        } else if list.ordered {
            Text("\(list.start + index).")
                .font(.system(size: theme.baseSize * 0.95, design: theme.design))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text(Self.bullets[min(level, Self.bullets.count - 1)])
                .font(.system(size: theme.baseSize))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tables

struct TableView: View {
    let table: MDTable
    let context: RenderContext

    var body: some View {
        let theme = context.theme
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 18, verticalSpacing: 9) {
                GridRow {
                    ForEach(Array(table.header.enumerated()), id: \.offset) { index, cell in
                        Text(context.inline(cell, font: .system(size: theme.baseSize * 0.95,
                                                                weight: .semibold,
                                                                design: theme.design)))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .gridColumnAlignment(alignment(index))
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(context.inline(cell, font: .system(size: theme.baseSize * 0.95, design: theme.design)))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if rowIndex < table.rows.count - 1 {
                        Divider().opacity(0.35).gridCellUnsizedAxes(.horizontal)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.codeBorder, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alignment(_ index: Int) -> HorizontalAlignment {
        guard index < table.alignments.count else { return .leading }
        switch table.alignments[index] {
        case .center: return .center
        case .right: return .trailing
        default: return .leading
        }
    }
}

// MARK: - Images

struct MDImageView: View {
    let image: MDImageBlock
    let context: RenderContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let caption = image.title ?? (image.alt.isEmpty ? nil : image.alt) {
                Text(caption)
                    .font(context.theme.smallFont)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if let url = resolvedURL {
            if url.isFileURL {
                if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: nsImage.size.width, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    placeholder(symbol: "photo", text: String(format: String(localized: "Not found: %@"), url.lastPathComponent))
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    case .failure:
                        placeholder(symbol: "photo.badge.exclamationmark", text: image.source)
                    default:
                        placeholder(symbol: "photo", text: String(localized: "Loading…"))
                    }
                }
            }
        } else {
            placeholder(symbol: "photo", text: image.source)
        }
    }

    private var resolvedURL: URL? {
        let source = image.source.trimmingCharacters(in: .whitespaces)
        guard !source.isEmpty else { return nil }
        if source.hasPrefix("data:") { return nil }
        if let url = URL(string: source), let scheme = url.scheme, scheme != "file" {
            return url
        }
        let cleaned = source.removingPercentEncoding ?? source
        if cleaned.hasPrefix("/") { return URL(fileURLWithPath: cleaned) }
        if cleaned.hasPrefix("~") { return URL(fileURLWithPath: (cleaned as NSString).expandingTildeInPath) }
        guard let base = context.baseURL else { return nil }
        return URL(fileURLWithPath: cleaned, relativeTo: base).standardizedFileURL
    }

    private func placeholder(symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text).lineLimit(1).truncationMode(.middle)
        }
        .font(context.theme.smallFont)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }
}

// MARK: - Front matter

struct FrontMatterView: View {
    let pairs: [MDPair]
    let theme: MarkdownTheme
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(pairs) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pair.key)
                            .font(.system(size: theme.baseSize * 0.8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(pair.value)
                            .font(.system(size: theme.baseSize * 0.8, design: theme.design))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                Text("Metadata")
                if let title = pairs.first(where: { $0.key.lowercased() == "title" })?.value, !expanded {
                    Text("· \(title)").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: theme.baseSize * 0.82))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

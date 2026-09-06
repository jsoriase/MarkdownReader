import Foundation

/// Serialises the parsed document into self-contained HTML.
enum HTMLExporter {

    static func export(_ document: MDDocument, title: String, fragmentOnly: Bool = false) -> String {
        var body = ""
        for block in document.blocks {
            body += html(for: block, links: document.linkDefinitions)
        }
        if fragmentOnly { return body }
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        <article>
        \(body)
        </article>
        </body>
        </html>
        """
    }

    // MARK: - Blocks

    private static func html(for block: MDBlock, links: [String: String]) -> String {
        switch block {
        case .heading(let heading):
            return "<h\(heading.level) id=\"\(heading.id)\">\(inline(heading.markdown, links: links))</h\(heading.level)>\n"

        case .paragraph(_, let markdown, _):
            return "<p>\(inline(markdown, links: links))</p>\n"

        case .code(let code):
            let cls = code.language.map { " class=\"language-\($0)\"" } ?? ""
            return "<pre><code\(cls)>\(escape(code.code))</code></pre>\n"

        case .quote(_, let blocks):
            return "<blockquote>\n" + blocks.map { html(for: $0, links: links) }.joined() + "</blockquote>\n"

        case .list(let list):
            let tag = list.ordered ? "ol" : "ul"
            let start = list.ordered && list.start != 1 ? " start=\"\(list.start)\"" : ""
            var out = "<\(tag)\(start)>\n"
            for item in list.items {
                var content = item.blocks.map { html(for: $0, links: links) }.joined()
                if list.tight {
                    content = content
                        .replacingOccurrences(of: "<p>", with: "")
                        .replacingOccurrences(of: "</p>\n", with: "")
                }
                if let checked = item.checked {
                    let box = "<input type=\"checkbox\" disabled\(checked ? " checked" : "")> "
                    out += "<li class=\"task\">\(box)\(content)</li>\n"
                } else {
                    out += "<li>\(content)</li>\n"
                }
            }
            return out + "</\(tag)>\n"

        case .table(let table):
            var out = "<table>\n<thead><tr>"
            for (index, cell) in table.header.enumerated() {
                out += "<th\(styleAttr(table, index))>\(inline(cell, links: links))</th>"
            }
            out += "</tr></thead>\n<tbody>\n"
            for row in table.rows {
                out += "<tr>"
                for (index, cell) in row.enumerated() {
                    out += "<td\(styleAttr(table, index))>\(inline(cell, links: links))</td>"
                }
                out += "</tr>\n"
            }
            return out + "</tbody>\n</table>\n"

        case .rule:
            return "<hr>\n"

        case .image(let image):
            let alt = escape(image.alt)
            let title = image.title.map { " title=\"\(escape($0))\"" } ?? ""
            return "<p class=\"figure\"><img src=\"\(escape(image.source))\" alt=\"\(alt)\"\(title)></p>\n"

        case .html(_, let raw, _):
            return raw + "\n"

        case .frontMatter(_, let pairs):
            guard !pairs.isEmpty else { return "" }
            let rows = pairs.map { "<tr><th>\(escape($0.key))</th><td>\(escape($0.value))</td></tr>" }.joined()
            return "<table class=\"frontmatter\">\(rows)</table>\n"
        }
    }

    private static func styleAttr(_ table: MDTable, _ index: Int) -> String {
        guard index < table.alignments.count else { return "" }
        switch table.alignments[index] {
        case .left: return " style=\"text-align:left\""
        case .center: return " style=\"text-align:center\""
        case .right: return " style=\"text-align:right\""
        case .none: return ""
        }
    }

    // MARK: - Inline

    private static func inline(_ markdown: String, links: [String: String]) -> String {
        let attributed = InlineRenderer.parsed(markdown, links: links)
        var out = ""
        for run in attributed.runs {
            var piece = escape(String(attributed[run.range].characters))
            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.code) { piece = "<code>\(piece)</code>" }
            if intent.contains(.stronglyEmphasized) { piece = "<strong>\(piece)</strong>" }
            if intent.contains(.emphasized) { piece = "<em>\(piece)</em>" }
            if intent.contains(.strikethrough) { piece = "<del>\(piece)</del>" }
            if let link = run.link {
                piece = "<a href=\"\(escape(link.absoluteString))\">\(piece)</a>"
            }
            out += piece
        }
        return out.replacingOccurrences(of: "\n", with: "<br>\n")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let css = """
    :root { color-scheme: light dark; }
    body { margin: 0; padding: 3rem 1.5rem; background: #fff; color: #1d1d1f;
           font: 16px/1.65 -apple-system, BlinkMacSystemFont, "SF Pro Text", Helvetica, Arial, sans-serif; }
    article { max-width: 46rem; margin: 0 auto; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 2rem 0 .75rem; font-weight: 650; }
    h1 { font-size: 2rem; } h2 { font-size: 1.55rem; } h3 { font-size: 1.25rem; }
    h1, h2 { border-bottom: 1px solid rgba(128,128,128,.25); padding-bottom: .3rem; }
    p { margin: 0 0 1rem; }
    a { color: #0066cc; }
    code { font: .88em ui-monospace, SFMono-Regular, Menlo, monospace;
           background: rgba(128,128,128,.14); padding: .12em .35em; border-radius: 4px; }
    pre { background: rgba(128,128,128,.1); border: 1px solid rgba(128,128,128,.2);
          border-radius: 8px; padding: .9rem 1rem; overflow-x: auto; }
    pre code { background: none; padding: 0; }
    blockquote { margin: 0 0 1rem; padding: .1rem 0 .1rem 1rem;
                 border-left: 3px solid rgba(128,128,128,.4); color: #555; }
    table { border-collapse: collapse; margin: 0 0 1.2rem; display: block; overflow-x: auto; }
    th, td { border: 1px solid rgba(128,128,128,.28); padding: .45rem .7rem; text-align: left; }
    th { background: rgba(128,128,128,.1); }
    img { max-width: 100%; border-radius: 6px; }
    hr { border: none; border-top: 1px solid rgba(128,128,128,.3); margin: 2rem 0; }
    li.task { list-style: none; margin-left: -1.2rem; }
    .frontmatter { font-size: .85em; opacity: .8; }
    @media (prefers-color-scheme: dark) {
      body { background: #1c1c1e; color: #f2f2f7; }
      a { color: #6ea8fe; }
      blockquote { color: #b0b0b8; }
    }
    """
}

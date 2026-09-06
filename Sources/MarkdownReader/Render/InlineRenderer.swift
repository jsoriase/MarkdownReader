import SwiftUI

struct InlineStyle {
    var font: Font
    var codeFont: Font
    var codeBackground: Color
    var codeForeground: Color
    var linkColor: Color
    var foreground: Color?
}

/// Convierte texto Markdown "inline" (negritas, cursivas, código, enlaces…)
/// en `AttributedString` listo para `Text`.
///
/// El parseo lo hace Foundation (cmark); aquí se resuelven referencias,
/// autoenlaces y el estilo visual de cada tramo.
enum InlineRenderer {

    private final class Box {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    private static let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 4000
        return c
    }()

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    // MARK: - Público

    static func render(_ markdown: String, style: InlineStyle, links: [String: String] = [:]) -> AttributedString {
        var attr = parsed(markdown, links: links)
        apply(style, to: &attr)
        return attr
    }

    // MARK: - Parseo

    static func parsed(_ markdown: String, links: [String: String] = [:]) -> AttributedString {
        let source = resolveReferences(markdown, definitions: links)
        if let hit = cache.object(forKey: source as NSString) { return hit.value }

        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible)

        var attr = (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
        detectAutolinks(&attr)
        cache.setObject(Box(attr), forKey: source as NSString)
        return attr
    }

    // MARK: - Estilo

    private static func apply(_ style: InlineStyle, to attr: inout AttributedString) {
        var codeRanges: [Range<AttributedString.Index>] = []
        var fonts: [(Range<AttributedString.Index>, Font)] = []
        var strikes: [Range<AttributedString.Index>] = []
        var linkRanges: [Range<AttributedString.Index>] = []

        for run in attr.runs {
            let intent = run.inlinePresentationIntent ?? []
            var font = style.font
            if intent.contains(.code) {
                font = style.codeFont
                codeRanges.append(run.range)
            }
            if intent.contains(.stronglyEmphasized) { font = font.bold() }
            if intent.contains(.emphasized) { font = font.italic() }
            fonts.append((run.range, font))
            if intent.contains(.strikethrough) { strikes.append(run.range) }
            if run.link != nil { linkRanges.append(run.range) }
        }

        if let foreground = style.foreground { attr.foregroundColor = foreground }
        for (range, font) in fonts { attr[range].font = font }
        for range in codeRanges {
            attr[range].backgroundColor = style.codeBackground
            attr[range].foregroundColor = style.codeForeground
        }
        for range in strikes { attr[range].strikethroughStyle = .single }
        for range in linkRanges { attr[range].foregroundColor = style.linkColor }
    }

    // MARK: - Autoenlaces

    private static func detectAutolinks(_ attr: inout AttributedString) {
        guard let detector else { return }
        let plain = String(attr.characters)
        guard plain.contains("://") || plain.contains("www.") || plain.contains("@") else { return }
        let matches = detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain))
        guard !matches.isEmpty else { return }

        for match in matches {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: plain),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attr),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attr)
            else { continue }
            let range = lower..<upper
            var skip = false
            for run in attr[range].runs {
                if run.link != nil { skip = true; break }
                if let intent = run.inlinePresentationIntent, intent.contains(.code) { skip = true; break }
            }
            if !skip { attr[range].link = url }
        }
    }

    // MARK: - Enlaces por referencia

    static func resolveReferences(_ markdown: String, definitions: [String: String]) -> String {
        guard !definitions.isEmpty, markdown.contains("[") else { return markdown }
        var out = markdown

        out = replace(out, pattern: "(!?)\\[([^\\[\\]]*)\\]\\[([^\\[\\]]*)\\]") { groups in
            let bang = groups[1]
            let text = groups[2]
            let label = groups[3].isEmpty ? groups[2] : groups[3]
            guard let dest = definitions[label.lowercased()] else { return nil }
            return "\(bang)[\(text)](\(dest))"
        }

        out = replace(out, pattern: "(!?)\\[([^\\[\\]]+)\\](?![\\(\\[:])") { groups in
            guard let dest = definitions[groups[2].lowercased()] else { return nil }
            return "\(groups[1])[\(groups[2])](\(dest))"
        }

        return out
    }

    private static func replace(_ input: String, pattern: String, transform: ([String]) -> String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return input }
        var result = input
        for match in matches.reversed() {
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let r = match.range(at: i)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            guard let replacement = transform(groups),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

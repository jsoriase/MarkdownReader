import XCTest
@testable import MarkdownReader

final class ParserTests: XCTestCase {

    private func parse(_ text: String) -> MDDocument {
        MarkdownParser.parse(text)
    }

    func testHeadingsAndSlugs() {
        let doc = parse("# One\n\n## Two three\n\n## Two three\n")
        XCTAssertEqual(doc.headings.map(\.level), [1, 2, 2])
        XCTAssertEqual(doc.headings.map(\.id), ["one", "two-three", "two-three-1"])
    }

    func testSetextHeadings() {
        let doc = parse("Título\n======\n\nOther\n----\n")
        XCTAssertEqual(doc.headings.map(\.level), [1, 2])
        XCTAssertEqual(doc.headings.map(\.plain), ["Título", "Other"])
    }

    func testParagraphJoinsSoftBreaks() {
        let doc = parse("one line\ncontinues here\n")
        guard case .paragraph(_, let markdown, _) = doc.blocks.first else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(markdown, "one line continues here")
    }

    func testFencedCodeKeepsContentAndLanguage() {
        let doc = parse("```swift\nlet x = 1\n\n# not a heading\n```\n")
        guard case .code(let code) = doc.blocks.first else {
            return XCTFail("expected a code block")
        }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.code, "let x = 1\n\n# not a heading")
    }

    func testNestedAndTaskLists() {
        let doc = parse("""
        - one
          - nested
        - [x] done
        - [ ] pending
        """)
        guard case .list(let list) = doc.blocks.first else {
            return XCTFail("expected a list")
        }
        XCTAssertEqual(list.items.count, 3)
        XCTAssertTrue(list.tight)
        XCTAssertEqual(list.items[1].checked, true)
        XCTAssertEqual(list.items[2].checked, false)
        guard case .list(let nested) = list.items[0].blocks.last else {
            return XCTFail("expected a nested list")
        }
        XCTAssertEqual(nested.items.count, 1)
    }

    func testOrderedListStart() {
        let doc = parse("3. three\n4. four\n")
        guard case .list(let list) = doc.blocks.first else {
            return XCTFail("expected a list")
        }
        XCTAssertTrue(list.ordered)
        XCTAssertEqual(list.start, 3)
    }

    func testTableWithAlignments() {
        let doc = parse("""
        | a | b | c |
        |:--|:-:|--:|
        | 1 | 2 | 3 |
        """)
        guard case .table(let table) = doc.blocks.first else {
            return XCTFail("expected a table")
        }
        XCTAssertEqual(table.header, ["a", "b", "c"])
        XCTAssertEqual(table.rows, [["1", "2", "3"]])
        XCTAssertEqual(table.alignments.count, 3)
        if case .left = table.alignments[0] {} else { XCTFail("left") }
        if case .center = table.alignments[1] {} else { XCTFail("center") }
        if case .right = table.alignments[2] {} else { XCTFail("right") }
    }

    func testBlockQuoteWithNestedBlocks() {
        let doc = parse("> quote\n> - bullet\n")
        guard case .quote(_, let blocks) = doc.blocks.first else {
            return XCTFail("expected a block quote")
        }
        XCTAssertEqual(blocks.count, 2)
    }

    func testThematicBreakIsNotAList() {
        let doc = parse("text\n\n---\n\nmore text\n")
        guard case .rule = doc.blocks[1] else {
            return XCTFail("expected a thematic break")
        }
    }

    func testFrontMatter() {
        let doc = parse("---\ntitle: Hello\nauthor: Me\n---\n\n# Body\n")
        guard case .frontMatter(_, let pairs) = doc.blocks.first else {
            return XCTFail("expected front matter")
        }
        XCTAssertEqual(pairs.map(\.key), ["title", "author"])
        XCTAssertEqual(doc.headings.count, 1)
    }

    func testLinkDefinitionsAreCollected() {
        let doc = parse("See [docs][d].\n\n[d]: https://example.com\n")
        XCTAssertEqual(doc.linkDefinitions["d"], "https://example.com")
        XCTAssertEqual(doc.blocks.count, 1)
    }

    func testStandaloneImageBecomesImageBlock() {
        let doc = parse("![cat](cat.png)\n")
        guard case .image(let image) = doc.blocks.first else {
            return XCTFail("expected an image")
        }
        XCTAssertEqual(image.source, "cat.png")
        XCTAssertEqual(image.alt, "cat")
    }

    func testIndentedCodeBlock() {
        let doc = parse("paragraph\n\n    code\n    more\n")
        guard case .code(let code) = doc.blocks[1] else {
            return XCTFail("expected an indented code block")
        }
        XCTAssertEqual(code.code, "code\nmore")
        XCTAssertNil(code.language)
    }

    func testCRLFIsNormalized() {
        let doc = parse("# Título\r\n\r\ntext\r\n")
        XCTAssertEqual(doc.headings.first?.plain, "Título")
        XCTAssertEqual(doc.blocks.count, 2)
    }

    func testHeadingLinesMapToSource() {
        let text = "first\n\n## Second\n\ntext\n"
        let doc = parse(text)
        XCTAssertEqual(doc.headings.first?.line, 2)
    }
}

final class DocumentTests: XCTestCase {

    func testRoundTripPreservesText() throws {
        let original = "# Hello\n\nAccents: ñ á ü — and emoji 🎉\n"
        let document = MarkdownDocument(text: original)
        let reloaded = try MarkdownDocument(data: document.encodedData())
        XCTAssertEqual(reloaded.text, original)
    }

    func testLatin1FallbackAndBOM() throws {
        let latin1 = try XCTUnwrap("café".data(using: .isoLatin1))
        let document = try MarkdownDocument(data: latin1)
        XCTAssertEqual(document.text, "café")
        XCTAssertEqual(document.encoding, .isoLatin1)
        XCTAssertEqual(document.encodedData(), latin1)

        let withBOM = try XCTUnwrap("\u{FEFF}# Título".data(using: .utf8))
        XCTAssertEqual(try MarkdownDocument(data: withBOM).text, "# Título")
    }

    func testTaskToggleEditsTheRightLine() {
        var document = MarkdownDocument(text: "- [ ] one\n- [ ] two\n")
        document.setTask(line: 1, checked: true)
        XCTAssertEqual(document.text, "- [ ] one\n- [x] two\n")
        document.setTask(line: 1, checked: false)
        XCTAssertEqual(document.text, "- [ ] one\n- [ ] two\n")
    }

    func testTaskToggleIgnoresInvalidLines() {
        var document = MarkdownDocument(text: "no tasks\n")
        document.setTask(line: 0, checked: true)
        document.setTask(line: 99, checked: true)
        XCTAssertEqual(document.text, "no tasks\n")
    }

    func testStatistics() {
        let document = MarkdownDocument(text: "one two three\nfour\n")
        XCTAssertEqual(document.wordCount, 4)
        XCTAssertEqual(document.lineCount, 3)
        XCTAssertEqual(document.readingMinutes, 1)
    }
}

final class HTMLExportTests: XCTestCase {

    func testExportsHeadingsListsAndCode() {
        let doc = MarkdownParser.parse("""
        # Título

        Text with **bold** and `code`.

        - one
        - two

        ```swift
        let x = 1 < 2
        ```
        """)
        let html = HTMLExporter.export(doc, title: "Prueba")
        XCTAssertTrue(html.contains("<h1 id=\"título\">Título</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("class=\"language-swift\""))
        XCTAssertTrue(html.contains("let x = 1 &lt; 2"))
    }

    func testFragmentHasNoDocumentChrome() {
        let doc = MarkdownParser.parse("Hello")
        let fragment = HTMLExporter.export(doc, title: "x", fragmentOnly: true)
        XCTAssertFalse(fragment.contains("<!DOCTYPE"))
        XCTAssertEqual(fragment.trimmingCharacters(in: .whitespacesAndNewlines), "<p>Hello</p>")
    }
}

final class InlineTests: XCTestCase {

    func testReferenceLinksAreResolved() {
        let result = InlineRenderer.resolveReferences("See [docs][d] and [other].",
                                                      definitions: ["d": "https://a.example",
                                                                    "other": "https://b.example"])
        XCTAssertEqual(result, "See [docs](https://a.example) and [other](https://b.example).")
    }

    func testPlainTextStripsMarkup() {
        XCTAssertEqual(MarkdownParser.plainText("**Hello** `world` [x](y)"), "Hello world x")
    }
}

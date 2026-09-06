import XCTest
@testable import MarkdownReader

final class ParserTests: XCTestCase {

    private func parse(_ text: String) -> MDDocument {
        MarkdownParser.parse(text)
    }

    func testHeadingsAndSlugs() {
        let doc = parse("# Uno\n\n## Dos tres\n\n## Dos tres\n")
        XCTAssertEqual(doc.headings.map(\.level), [1, 2, 2])
        XCTAssertEqual(doc.headings.map(\.id), ["uno", "dos-tres", "dos-tres-1"])
    }

    func testSetextHeadings() {
        let doc = parse("Título\n======\n\nOtro\n----\n")
        XCTAssertEqual(doc.headings.map(\.level), [1, 2])
        XCTAssertEqual(doc.headings.map(\.plain), ["Título", "Otro"])
    }

    func testParagraphJoinsSoftBreaks() {
        let doc = parse("una línea\nsigue aquí\n")
        guard case .paragraph(_, let markdown, _) = doc.blocks.first else {
            return XCTFail("se esperaba un párrafo")
        }
        XCTAssertEqual(markdown, "una línea sigue aquí")
    }

    func testFencedCodeKeepsContentAndLanguage() {
        let doc = parse("```swift\nlet x = 1\n\n# no es título\n```\n")
        guard case .code(let code) = doc.blocks.first else {
            return XCTFail("se esperaba un bloque de código")
        }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.code, "let x = 1\n\n# no es título")
    }

    func testNestedAndTaskLists() {
        let doc = parse("""
        - uno
          - anidado
        - [x] hecha
        - [ ] pendiente
        """)
        guard case .list(let list) = doc.blocks.first else {
            return XCTFail("se esperaba una lista")
        }
        XCTAssertEqual(list.items.count, 3)
        XCTAssertTrue(list.tight)
        XCTAssertEqual(list.items[1].checked, true)
        XCTAssertEqual(list.items[2].checked, false)
        guard case .list(let nested) = list.items[0].blocks.last else {
            return XCTFail("se esperaba una lista anidada")
        }
        XCTAssertEqual(nested.items.count, 1)
    }

    func testOrderedListStart() {
        let doc = parse("3. tres\n4. cuatro\n")
        guard case .list(let list) = doc.blocks.first else {
            return XCTFail("se esperaba una lista")
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
            return XCTFail("se esperaba una tabla")
        }
        XCTAssertEqual(table.header, ["a", "b", "c"])
        XCTAssertEqual(table.rows, [["1", "2", "3"]])
        XCTAssertEqual(table.alignments.count, 3)
        if case .left = table.alignments[0] {} else { XCTFail("izquierda") }
        if case .center = table.alignments[1] {} else { XCTFail("centro") }
        if case .right = table.alignments[2] {} else { XCTFail("derecha") }
    }

    func testBlockQuoteWithNestedBlocks() {
        let doc = parse("> cita\n> - punto\n")
        guard case .quote(_, let blocks) = doc.blocks.first else {
            return XCTFail("se esperaba una cita")
        }
        XCTAssertEqual(blocks.count, 2)
    }

    func testThematicBreakIsNotAList() {
        let doc = parse("texto\n\n---\n\nmás texto\n")
        guard case .rule = doc.blocks[1] else {
            return XCTFail("se esperaba una línea horizontal")
        }
    }

    func testFrontMatter() {
        let doc = parse("---\ntitle: Hola\nautor: Yo\n---\n\n# Cuerpo\n")
        guard case .frontMatter(_, let pairs) = doc.blocks.first else {
            return XCTFail("se esperaban metadatos")
        }
        XCTAssertEqual(pairs.map(\.key), ["title", "autor"])
        XCTAssertEqual(doc.headings.count, 1)
    }

    func testLinkDefinitionsAreCollected() {
        let doc = parse("Ver [docs][d].\n\n[d]: https://example.com\n")
        XCTAssertEqual(doc.linkDefinitions["d"], "https://example.com")
        XCTAssertEqual(doc.blocks.count, 1)
    }

    func testStandaloneImageBecomesImageBlock() {
        let doc = parse("![gato](gato.png)\n")
        guard case .image(let image) = doc.blocks.first else {
            return XCTFail("se esperaba una imagen")
        }
        XCTAssertEqual(image.source, "gato.png")
        XCTAssertEqual(image.alt, "gato")
    }

    func testIndentedCodeBlock() {
        let doc = parse("párrafo\n\n    código\n    más\n")
        guard case .code(let code) = doc.blocks[1] else {
            return XCTFail("se esperaba código indentado")
        }
        XCTAssertEqual(code.code, "código\nmás")
        XCTAssertNil(code.language)
    }

    func testCRLFIsNormalized() {
        let doc = parse("# Título\r\n\r\ntexto\r\n")
        XCTAssertEqual(doc.headings.first?.plain, "Título")
        XCTAssertEqual(doc.blocks.count, 2)
    }

    func testHeadingLinesMapToSource() {
        let text = "primera\n\n## Segundo\n\ntexto\n"
        let doc = parse(text)
        XCTAssertEqual(doc.headings.first?.line, 2)
    }
}

final class DocumentTests: XCTestCase {

    func testRoundTripPreservesText() throws {
        let original = "# Hola\n\nCon acentos: ñ á ü — y emoji 🎉\n"
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
        var document = MarkdownDocument(text: "- [ ] uno\n- [ ] dos\n")
        document.setTask(line: 1, checked: true)
        XCTAssertEqual(document.text, "- [ ] uno\n- [x] dos\n")
        document.setTask(line: 1, checked: false)
        XCTAssertEqual(document.text, "- [ ] uno\n- [ ] dos\n")
    }

    func testTaskToggleIgnoresInvalidLines() {
        var document = MarkdownDocument(text: "sin tareas\n")
        document.setTask(line: 0, checked: true)
        document.setTask(line: 99, checked: true)
        XCTAssertEqual(document.text, "sin tareas\n")
    }

    func testStatistics() {
        let document = MarkdownDocument(text: "uno dos tres\ncuatro\n")
        XCTAssertEqual(document.wordCount, 4)
        XCTAssertEqual(document.lineCount, 3)
        XCTAssertEqual(document.readingMinutes, 1)
    }
}

final class HTMLExportTests: XCTestCase {

    func testExportsHeadingsListsAndCode() {
        let doc = MarkdownParser.parse("""
        # Título

        Texto con **negrita** y `código`.

        - uno
        - dos

        ```swift
        let x = 1 < 2
        ```
        """)
        let html = HTMLExporter.export(doc, title: "Prueba")
        XCTAssertTrue(html.contains("<h1 id=\"título\">Título</h1>"))
        XCTAssertTrue(html.contains("<strong>negrita</strong>"))
        XCTAssertTrue(html.contains("<code>código</code>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("class=\"language-swift\""))
        XCTAssertTrue(html.contains("let x = 1 &lt; 2"))
    }

    func testFragmentHasNoDocumentChrome() {
        let doc = MarkdownParser.parse("Hola")
        let fragment = HTMLExporter.export(doc, title: "x", fragmentOnly: true)
        XCTAssertFalse(fragment.contains("<!DOCTYPE"))
        XCTAssertEqual(fragment.trimmingCharacters(in: .whitespacesAndNewlines), "<p>Hola</p>")
    }
}

final class InlineTests: XCTestCase {

    func testReferenceLinksAreResolved() {
        let result = InlineRenderer.resolveReferences("Ver [docs][d] y [otro].",
                                                      definitions: ["d": "https://a.example",
                                                                    "otro": "https://b.example"])
        XCTAssertEqual(result, "Ver [docs](https://a.example) y [otro](https://b.example).")
    }

    func testPlainTextStripsMarkup() {
        XCTAssertEqual(MarkdownParser.plainText("**Hola** `mundo` [x](y)"), "Hola mundo x")
    }
}

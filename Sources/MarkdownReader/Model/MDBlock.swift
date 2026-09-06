import Foundation

/// Una línea del fichero original, conservando su número para poder
/// mapear elementos renderizados de vuelta al texto fuente.
struct SrcLine {
    let number: Int
    let text: String
}

struct MDHeading: Identifiable, Hashable {
    let id: String      // slug único, usado como ancla de scroll
    let level: Int
    let markdown: String
    let plain: String
    let line: Int
}

struct MDCode: Identifiable, Hashable {
    let id: String
    let language: String?
    let code: String
    let line: Int
}

struct MDListItem: Identifiable {
    let id: String
    let checked: Bool?
    let checkboxLine: Int?
    let blocks: [MDBlock]
}

struct MDList: Identifiable {
    let id: String
    let ordered: Bool
    let start: Int
    let tight: Bool
    let items: [MDListItem]
}

enum MDAlignment {
    case none, left, center, right
}

struct MDTable: Identifiable {
    let id: String
    let header: [String]
    let alignments: [MDAlignment]
    let rows: [[String]]
}

struct MDImageBlock: Identifiable, Hashable {
    let id: String
    let source: String
    let alt: String
    let title: String?
}

struct MDPair: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let value: String
}

indirect enum MDBlock: Identifiable {
    case heading(MDHeading)
    case paragraph(id: String, markdown: String, line: Int)
    case code(MDCode)
    case quote(id: String, blocks: [MDBlock])
    case list(MDList)
    case table(MDTable)
    case rule(id: String)
    case image(MDImageBlock)
    case html(id: String, raw: String, text: String)
    case frontMatter(id: String, pairs: [MDPair])

    var id: String {
        switch self {
        case .heading(let h): return h.id
        case .paragraph(let id, _, _): return id
        case .code(let c): return c.id
        case .quote(let id, _): return id
        case .list(let l): return l.id
        case .table(let t): return t.id
        case .rule(let id): return id
        case .image(let i): return i.id
        case .html(let id, _, _): return id
        case .frontMatter(let id, _): return id
        }
    }
}

struct MDDocument {
    var blocks: [MDBlock] = []
    var headings: [MDHeading] = []
    /// Definiciones de enlaces por referencia: `[etiqueta]: url "título"`
    var linkDefinitions: [String: String] = [:]

    static let empty = MDDocument()
}

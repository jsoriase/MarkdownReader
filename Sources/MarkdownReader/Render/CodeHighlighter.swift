import SwiftUI

/// Resaltado de sintaxis ligero para los bloques de código.
/// No pretende ser un analizador completo: reconoce comentarios, cadenas,
/// números y palabras clave, que es el 90 % del valor visual.
enum CodeHighlighter {

    struct Palette {
        var keyword: Color
        var string: Color
        var comment: Color
        var number: Color
        var type: Color
        var function: Color
        var key: Color
        var plain: Color

        static func forScheme(_ scheme: ColorScheme) -> Palette {
            if scheme == .dark {
                return Palette(
                    keyword: Color(red: 0.98, green: 0.47, blue: 0.76),
                    string: Color(red: 1.00, green: 0.56, blue: 0.50),
                    comment: Color(red: 0.55, green: 0.60, blue: 0.62),
                    number: Color(red: 0.84, green: 0.77, blue: 1.00),
                    type: Color(red: 0.42, green: 0.87, blue: 0.90),
                    function: Color(red: 0.53, green: 0.76, blue: 1.00),
                    key: Color(red: 0.62, green: 0.90, blue: 0.66),
                    plain: Color(red: 0.88, green: 0.89, blue: 0.91))
            }
            return Palette(
                keyword: Color(red: 0.68, green: 0.09, blue: 0.55),
                string: Color(red: 0.75, green: 0.14, blue: 0.11),
                comment: Color(red: 0.42, green: 0.47, blue: 0.49),
                number: Color(red: 0.20, green: 0.16, blue: 0.72),
                type: Color(red: 0.06, green: 0.42, blue: 0.50),
                function: Color(red: 0.14, green: 0.33, blue: 0.70),
                key: Color(red: 0.24, green: 0.45, blue: 0.20),
                plain: Color(red: 0.16, green: 0.17, blue: 0.19))
        }
    }

    struct Spec {
        var lineComments: [String] = []
        var blockComment: (open: String, close: String)? = nil
        var quotes: [Character] = ["\"", "'"]
        var keywords: Set<String> = []
        var types: Set<String> = []
        var markup = false
        var keyValue = false
    }

    // MARK: - Caché

    private final class Box {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    private static let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 500
        return c
    }()

    // MARK: - API

    static func highlight(_ code: String, language: String?, font: Font, scheme: ColorScheme) -> AttributedString {
        let lang = normalize(language)
        let key = "\(scheme == .dark ? "d" : "l")|\(lang ?? "-")|\(code)" as NSString
        if let hit = cache.object(forKey: key) { return hit.value }

        let palette = Palette.forScheme(scheme)
        var result: AttributedString

        if lang == "diff" {
            result = highlightDiff(code, palette: palette)
        } else if let lang, let spec = spec(for: lang) {
            result = tokenize(code, spec: spec, palette: palette)
        } else {
            result = AttributedString(code)
        }
        result.font = font
        if code.utf8.count < 40_000 { cache.setObject(Box(result), forKey: key) }
        return result
    }

    static func displayName(for language: String?) -> String? {
        guard let lang = language?.trimmingCharacters(in: .whitespaces), !lang.isEmpty else { return nil }
        let names = [
            "swift": "Swift", "js": "JavaScript", "javascript": "JavaScript",
            "ts": "TypeScript", "typescript": "TypeScript", "jsx": "JSX", "tsx": "TSX",
            "py": "Python", "python": "Python", "rb": "Ruby", "ruby": "Ruby",
            "go": "Go", "rs": "Rust", "rust": "Rust", "java": "Java", "kt": "Kotlin",
            "kotlin": "Kotlin", "c": "C", "cpp": "C++", "cc": "C++", "h": "C",
            "hpp": "C++", "objc": "Objective-C", "m": "Objective-C", "cs": "C#",
            "csharp": "C#", "sh": "Shell", "bash": "Bash", "zsh": "Zsh", "shell": "Shell",
            "sql": "SQL", "php": "PHP", "css": "CSS", "scss": "SCSS", "html": "HTML",
            "xml": "XML", "json": "JSON", "yaml": "YAML", "yml": "YAML", "toml": "TOML",
            "diff": "Diff", "md": "Markdown", "markdown": "Markdown", "text": "Texto"
        ]
        return names[lang.lowercased()] ?? lang
    }

    // MARK: - Lenguajes

    private static func normalize(_ language: String?) -> String? {
        guard var l = language?.lowercased().trimmingCharacters(in: .whitespaces), !l.isEmpty else { return nil }
        if let brace = l.firstIndex(where: { $0 == "{" || $0 == "," || $0 == ":" }) { l = String(l[l.startIndex..<brace]) }
        return l.isEmpty ? nil : l
    }

    private static func spec(for language: String) -> Spec? {
        switch language {
        case "swift":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"),
                        keywords: ["func", "let", "var", "if", "else", "guard", "return", "struct", "class", "enum", "protocol", "extension", "import", "for", "in", "while", "switch", "case", "default", "break", "continue", "self", "Self", "init", "deinit", "throws", "rethrows", "try", "catch", "do", "defer", "async", "await", "static", "private", "public", "internal", "fileprivate", "open", "final", "lazy", "weak", "unowned", "some", "any", "where", "as", "is", "nil", "true", "false", "typealias", "associatedtype", "subscript", "inout", "mutating", "override", "convenience", "required", "indirect", "repeat", "fallthrough", "get", "set", "willSet", "didSet", "actor", "throw", "operator", "precedencegroup"],
                        types: ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional", "Result", "Data", "Date", "URL", "View", "Text", "Color", "Font"])
        case "js", "javascript", "jsx", "mjs", "cjs", "ts", "typescript", "tsx":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'", "`"],
                        keywords: ["const", "let", "var", "function", "return", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "new", "class", "extends", "super", "this", "import", "export", "from", "as", "async", "await", "try", "catch", "finally", "throw", "typeof", "instanceof", "delete", "in", "of", "yield", "null", "undefined", "true", "false", "interface", "type", "enum", "implements", "private", "public", "protected", "readonly", "static", "void", "never", "any", "unknown", "satisfies", "declare"],
                        types: ["String", "Number", "Boolean", "Object", "Array", "Promise", "Map", "Set", "Date", "JSON", "Math", "console", "window", "document"])
        case "py", "python":
            return Spec(lineComments: ["#"], quotes: ["\"", "'"],
                        keywords: ["def", "class", "return", "if", "elif", "else", "for", "while", "break", "continue", "pass", "import", "from", "as", "with", "try", "except", "finally", "raise", "lambda", "yield", "global", "nonlocal", "del", "assert", "async", "await", "in", "is", "not", "and", "or", "None", "True", "False", "self", "match", "case"],
                        types: ["str", "int", "float", "bool", "list", "dict", "set", "tuple", "bytes", "print", "len", "range", "type", "object"])
        case "rb", "ruby":
            return Spec(lineComments: ["#"],
                        keywords: ["def", "end", "class", "module", "if", "elsif", "else", "unless", "while", "until", "for", "in", "do", "return", "yield", "begin", "rescue", "ensure", "raise", "require", "require_relative", "attr_accessor", "attr_reader", "attr_writer", "self", "nil", "true", "false", "and", "or", "not", "then", "case", "when", "puts", "lambda", "proc", "new"])
        case "go":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'", "`"],
                        keywords: ["package", "import", "func", "return", "if", "else", "for", "range", "switch", "case", "default", "break", "continue", "var", "const", "type", "struct", "interface", "map", "chan", "go", "defer", "select", "fallthrough", "goto", "nil", "true", "false"],
                        types: ["string", "int", "int64", "int32", "float64", "bool", "byte", "rune", "error", "any"])
        case "rs", "rust":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"),
                        keywords: ["fn", "let", "mut", "const", "static", "if", "else", "match", "loop", "while", "for", "in", "return", "break", "continue", "struct", "enum", "impl", "trait", "use", "mod", "pub", "crate", "self", "super", "as", "where", "dyn", "move", "ref", "unsafe", "async", "await", "type", "true", "false"],
                        types: ["String", "Vec", "Option", "Result", "Box", "Rc", "Arc", "u8", "u32", "u64", "i32", "i64", "f32", "f64", "usize", "bool", "str"])
        case "java", "kt", "kotlin":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"),
                        keywords: ["public", "private", "protected", "class", "interface", "extends", "implements", "new", "return", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "try", "catch", "finally", "throw", "throws", "static", "final", "void", "import", "package", "this", "super", "null", "true", "false", "fun", "val", "var", "object", "when", "data", "sealed", "override", "suspend", "companion", "init"],
                        types: ["String", "Int", "Integer", "Double", "Boolean", "List", "Map", "Set", "Array", "Long", "Float", "Unit", "Any"])
        case "c", "h", "cpp", "cc", "cxx", "hpp", "objc", "m", "mm", "cs", "csharp":
            return Spec(lineComments: ["//"], blockComment: ("/*", "*/"),
                        keywords: ["int", "char", "float", "double", "void", "long", "short", "signed", "unsigned", "struct", "union", "enum", "typedef", "static", "const", "extern", "return", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "sizeof", "goto", "class", "public", "private", "protected", "namespace", "template", "typename", "new", "delete", "this", "nullptr", "true", "false", "using", "virtual", "override", "auto", "include", "define", "import", "var", "string", "bool"])
        case "sh", "bash", "zsh", "shell", "console", "terminal", "fish":
            return Spec(lineComments: ["#"], quotes: ["\"", "'", "`"],
                        keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "export", "local", "source", "echo", "cd", "exit", "set", "unset", "read", "shift", "trap", "sudo", "true", "false"])
        case "sql":
            return Spec(lineComments: ["--"], blockComment: ("/*", "*/"),
                        keywords: ["select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create", "table", "drop", "alter", "add", "index", "join", "inner", "left", "right", "outer", "on", "group", "by", "order", "having", "limit", "offset", "as", "and", "or", "not", "null", "distinct", "union", "all", "case", "when", "then", "else", "end", "primary", "key", "foreign", "references", "default", "with"])
        case "php":
            return Spec(lineComments: ["//", "#"], blockComment: ("/*", "*/"),
                        keywords: ["function", "return", "if", "else", "elseif", "foreach", "for", "while", "class", "public", "private", "protected", "static", "new", "echo", "print", "require", "include", "use", "namespace", "try", "catch", "finally", "throw", "null", "true", "false", "array", "extends", "implements", "interface", "abstract", "const"])
        case "css", "scss", "sass", "less":
            return Spec(blockComment: ("/*", "*/"),
                        keywords: ["important", "media", "import", "keyframes", "supports", "include", "mixin", "extend", "root", "hover", "focus", "active", "before", "after"])
        case "html", "xml", "svg", "vue", "xhtml":
            return Spec(blockComment: ("<!--", "-->"), markup: true)
        case "json", "jsonc":
            return Spec(lineComments: ["//"], quotes: ["\""],
                        keywords: ["true", "false", "null"], keyValue: true)
        case "yaml", "yml", "toml", "ini", "conf", "properties", "env", "dotenv":
            return Spec(lineComments: ["#"], keywords: ["true", "false", "null", "yes", "no"], keyValue: true)
        case "makefile", "make", "dockerfile", "docker":
            return Spec(lineComments: ["#"],
                        keywords: ["FROM", "RUN", "CMD", "COPY", "ADD", "ENV", "WORKDIR", "EXPOSE", "ENTRYPOINT", "ARG", "LABEL", "VOLUME", "USER"])
        default:
            return nil
        }
    }

    // MARK: - Tokenizador

    private static func tokenize(_ code: String, spec: Spec, palette: Palette) -> AttributedString {
        var out = AttributedString()
        let chars = Array(code)
        var i = 0
        var pending = ""
        var atLineStart = true

        func flush() {
            guard !pending.isEmpty else { return }
            out.append(AttributedString(pending))
            pending = ""
        }

        func emit(_ text: String, _ color: Color) {
            flush()
            var piece = AttributedString(text)
            piece.foregroundColor = color
            out.append(piece)
        }

        func matches(_ token: String, at index: Int) -> Bool {
            guard index + token.count <= chars.count else { return false }
            return String(chars[index..<(index + token.count)]) == token
        }

        while i < chars.count {
            let ch = chars[i]

            // Comentario de bloque
            if let block = spec.blockComment, matches(block.open, at: i) {
                var j = i + block.open.count
                while j < chars.count, !matches(block.close, at: j) { j += 1 }
                let end = min(chars.count, j + block.close.count)
                emit(String(chars[i..<end]), palette.comment)
                i = end
                atLineStart = false
                continue
            }

            // Comentario de línea
            if spec.lineComments.contains(where: { matches($0, at: i) }) {
                var j = i
                while j < chars.count, chars[j] != "\n" { j += 1 }
                emit(String(chars[i..<j]), palette.comment)
                i = j
                continue
            }

            // Marcado tipo HTML
            if spec.markup, ch == "<" {
                var j = i + 1
                while j < chars.count, chars[j] != ">" { j += 1 }
                let end = min(chars.count, j + 1)
                emit(String(chars[i..<end]), palette.keyword)
                i = end
                atLineStart = false
                continue
            }

            // Cadenas
            if spec.quotes.contains(ch) {
                var j = i + 1
                var escaped = false
                while j < chars.count {
                    let c = chars[j]
                    if escaped { escaped = false; j += 1; continue }
                    if c == "\\" { escaped = true; j += 1; continue }
                    if c == ch { j += 1; break }
                    if c == "\n", ch != "`" { break }
                    j += 1
                }
                let text = String(chars[i..<min(j, chars.count)])
                var color = palette.string
                if spec.keyValue {
                    var k = j
                    while k < chars.count, chars[k] == " " { k += 1 }
                    if k < chars.count, chars[k] == ":" { color = palette.key }
                }
                emit(text, color)
                i = min(j, chars.count)
                atLineStart = false
                continue
            }

            // Números
            if ch.isNumber, i == 0 || !(chars[i - 1].isLetter || chars[i - 1] == "_") {
                var j = i
                while j < chars.count, chars[j].isHexDigit || chars[j] == "." || chars[j] == "x" || chars[j] == "_" { j += 1 }
                emit(String(chars[i..<j]), palette.number)
                i = j
                atLineStart = false
                continue
            }

            // Identificadores
            if ch.isLetter || ch == "_" || ch == "$" || ch == "@" || ch == "#" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" || chars[j] == "$" || chars[j] == "@" || chars[j] == "#" || (chars[j] == "-" && spec.keyValue) { j += 1 }
                let word = String(chars[i..<j])
                var k = j
                while k < chars.count, chars[k] == " " { k += 1 }
                let next: Character? = k < chars.count ? chars[k] : nil

                if spec.keywords.contains(word) {
                    emit(word, palette.keyword)
                } else if spec.types.contains(word) {
                    emit(word, palette.type)
                } else if spec.keyValue, atLineStart, next == ":" || next == "=" {
                    emit(word, palette.key)
                } else if next == "(" {
                    emit(word, palette.function)
                } else if let first = word.first, first.isUppercase, !spec.keyValue, word.count > 1 {
                    emit(word, palette.type)
                } else {
                    pending += word
                }
                i = j
                atLineStart = false
                continue
            }

            if ch == "\n" { atLineStart = true }
            else if ch != " " && ch != "\t" { atLineStart = false }
            pending.append(ch)
            i += 1
        }

        flush()
        return out
    }

    private static func highlightDiff(_ code: String, palette: Palette) -> AttributedString {
        var out = AttributedString()
        let added = Color(red: 0.20, green: 0.60, blue: 0.30)
        let removed = Color(red: 0.80, green: 0.25, blue: 0.25)
        let lines = code.components(separatedBy: "\n")
        for (idx, line) in lines.enumerated() {
            var piece = AttributedString(line + (idx == lines.count - 1 ? "" : "\n"))
            if line.hasPrefix("+++") || line.hasPrefix("---") || line.hasPrefix("diff ") || line.hasPrefix("index ") {
                piece.foregroundColor = palette.comment
            } else if line.hasPrefix("@@") {
                piece.foregroundColor = palette.type
            } else if line.hasPrefix("+") {
                piece.foregroundColor = added
            } else if line.hasPrefix("-") {
                piece.foregroundColor = removed
            }
            out.append(piece)
        }
        return out
    }
}

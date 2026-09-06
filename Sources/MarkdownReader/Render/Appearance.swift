import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case preview, source, split
    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return String(localized: "Preview")
        case .source: return String(localized: "Source")
        case .split: return String(localized: "Split")
        }
    }

    var symbol: String {
        switch self {
        case .preview: return "doc.richtext"
        case .source: return "chevron.left.forwardslash.chevron.right"
        case .split: return "rectangle.split.2x1"
        }
    }
}

enum PreviewFont: String, CaseIterable, Identifiable {
    case system, serif, rounded, mono
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .serif: return String(localized: "Serif")
        case .rounded: return String(localized: "Rounded")
        case .mono: return String(localized: "Monospaced")
        }
    }

    var design: Font.Design {
        switch self {
        case .system: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .mono: return .monospaced
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "Automatic")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Preferencias de la app, respaldadas por `UserDefaults`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var previewFontSize: Double { didSet { defaults.set(previewFontSize, forKey: "previewFontSize") } }
    @Published var editorFontSize: Double { didSet { defaults.set(editorFontSize, forKey: "editorFontSize") } }
    @Published var contentWidth: Double { didSet { defaults.set(contentWidth, forKey: "contentWidth") } }
    @Published var previewFont: PreviewFont { didSet { defaults.set(previewFont.rawValue, forKey: "previewFont") } }
    @Published var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    @Published var defaultMode: ViewMode { didSet { defaults.set(defaultMode.rawValue, forKey: "defaultMode") } }
    @Published var showLineNumbers: Bool { didSet { defaults.set(showLineNumbers, forKey: "showLineNumbers") } }
    @Published var highlightSource: Bool { didSet { defaults.set(highlightSource, forKey: "highlightSource") } }
    @Published var softWrap: Bool { didSet { defaults.set(softWrap, forKey: "softWrap") } }
    @Published var showStatusBar: Bool { didSet { defaults.set(showStatusBar, forKey: "showStatusBar") } }
    @Published var showOutline: Bool { didSet { defaults.set(showOutline, forKey: "showOutline") } }

    private init() {
        defaults.register(defaults: [
            "previewFontSize": 16.0,
            "editorFontSize": 13.0,
            "contentWidth": 760.0,
            "previewFont": PreviewFont.system.rawValue,
            "appearance": AppearanceMode.system.rawValue,
            "defaultMode": ViewMode.preview.rawValue,
            "showLineNumbers": true,
            "highlightSource": true,
            "softWrap": true,
            "showStatusBar": true,
            "showOutline": false
        ])
        previewFontSize = defaults.double(forKey: "previewFontSize")
        editorFontSize = defaults.double(forKey: "editorFontSize")
        contentWidth = defaults.double(forKey: "contentWidth")
        previewFont = PreviewFont(rawValue: defaults.string(forKey: "previewFont") ?? "") ?? .system
        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        defaultMode = ViewMode(rawValue: defaults.string(forKey: "defaultMode") ?? "") ?? .preview
        showLineNumbers = defaults.bool(forKey: "showLineNumbers")
        highlightSource = defaults.bool(forKey: "highlightSource")
        softWrap = defaults.bool(forKey: "softWrap")
        showStatusBar = defaults.bool(forKey: "showStatusBar")
        showOutline = defaults.bool(forKey: "showOutline")
    }

    func bumpPreviewFont(_ delta: Double) {
        previewFontSize = min(32, max(11, previewFontSize + delta))
    }

    func resetPreviewFont() {
        previewFontSize = 16
    }

    var theme: MarkdownTheme {
        MarkdownTheme(baseSize: previewFontSize, family: previewFont, maxWidth: contentWidth)
    }
}

/// Tipografía y métricas del render del Markdown.
struct MarkdownTheme: Equatable {
    var baseSize: CGFloat
    var family: PreviewFont
    var maxWidth: Double

    init(baseSize: Double, family: PreviewFont, maxWidth: Double) {
        self.baseSize = CGFloat(baseSize)
        self.family = family
        self.maxWidth = maxWidth
    }

    var design: Font.Design { family.design }

    var body: Font { .system(size: baseSize, design: design) }
    var codeFont: Font { .system(size: baseSize * 0.88, design: .monospaced) }
    var codeBlockFont: Font { .system(size: baseSize * 0.85, design: .monospaced) }
    var smallFont: Font { .system(size: baseSize * 0.78, design: design) }

    func headingFont(_ level: Int) -> Font {
        let scale: CGFloat
        switch level {
        case 1: scale = 1.95
        case 2: scale = 1.55
        case 3: scale = 1.28
        case 4: scale = 1.12
        case 5: scale = 1.0
        default: scale = 0.92
        }
        let weight: Font.Weight = level <= 2 ? .bold : .semibold
        return .system(size: baseSize * scale, weight: weight, design: design)
    }

    var lineSpacing: CGFloat { baseSize * 0.38 }
    var blockSpacing: CGFloat { baseSize * 0.9 }
    var tightSpacing: CGFloat { baseSize * 0.28 }

    var codeBackground: Color { Color.primary.opacity(0.06) }
    var codeBorder: Color { Color.primary.opacity(0.10) }
    var inlineCodeForeground: Color { Color(nsColor: .systemPink) }
    var linkColor: Color { Color.accentColor }

    var inlineStyle: InlineStyle {
        InlineStyle(font: body,
                    codeFont: codeFont,
                    codeBackground: codeBackground,
                    codeForeground: inlineCodeForeground,
                    linkColor: linkColor,
                    foreground: nil)
    }

    func inlineStyle(font: Font, foreground: Color? = nil) -> InlineStyle {
        InlineStyle(font: font,
                    codeFont: .system(size: baseSize * 0.88, design: .monospaced),
                    codeBackground: codeBackground,
                    codeForeground: inlineCodeForeground,
                    linkColor: linkColor,
                    foreground: foreground)
    }
}

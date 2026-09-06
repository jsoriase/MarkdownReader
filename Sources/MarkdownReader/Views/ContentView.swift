import SwiftUI

/// Acciones de la ventana activa, expuestas a los menús.
struct DocumentActions {
    var mode: Binding<ViewMode>
    var outlineVisible: Binding<Bool>
    var exportHTML: () -> Void
    var copyHTML: () -> Void
    var revealInFinder: () -> Void
}

struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @ObservedObject private var settings = AppSettings.shared

    @State private var mode: ViewMode = AppSettings.shared.defaultMode
    @State private var parsed: MDDocument = .empty
    @State private var scrollTarget: String?
    @State private var scrollToLine: Int?
    @State private var columns: NavigationSplitViewVisibility = AppSettings.shared.showOutline ? .all : .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            OutlineSidebar(headings: parsed.headings) { heading in
                if mode == .source {
                    scrollToLine = heading.line
                } else {
                    scrollTarget = heading.id
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 340)
        } detail: {
            VStack(spacing: 0) {
                content
                if settings.showStatusBar {
                    Divider()
                    StatusBar(document: document, parsed: parsed, mode: mode, fileURL: fileURL)
                }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
        .navigationTitle(fileURL?.lastPathComponent ?? String(localized: "Untitled"))
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .preferredColorScheme(settings.appearance.colorScheme)
        .task(id: document.text) { await reparse() }
        .onChange(of: columns) { _, value in
            settings.showOutline = (value != .detailOnly)
        }
        .focusedSceneValue(\.documentActions, DocumentActions(
            mode: $mode,
            outlineVisible: Binding(
                get: { columns != .detailOnly },
                set: { columns = $0 ? .all : .detailOnly }
            ),
            exportHTML: exportHTML,
            copyHTML: copyHTML,
            revealInFinder: revealInFinder
        ))
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .preview:
            preview
        case .source:
            editor
        case .split:
            HSplitView {
                editor
                    .frame(minWidth: 260)
                preview
                    .frame(minWidth: 300)
            }
        }
    }

    private var preview: some View {
        MarkdownPreview(document: parsed,
                        theme: settings.theme,
                        baseURL: fileURL,
                        onToggleTask: { line, checked in document.setTask(line: line, checked: checked) },
                        scrollTarget: $scrollTarget)
    }

    private var editor: some View {
        SourceEditor(text: $document.text,
                     fontSize: settings.editorFontSize,
                     showLineNumbers: settings.showLineNumbers,
                     highlight: settings.highlightSource,
                     softWrap: settings.softWrap,
                     scrollToLine: $scrollToLine)
    }

    private var subtitle: String {
        let words = document.wordCount
        guard words > 0 else { return "" }
        return String(format: String(localized: "%@ words · %@ min"),
                      words.formatted(), document.readingMinutes.formatted())
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("View mode", selection: $mode) {
                ForEach(ViewMode.allCases) { item in
                    Label(item.label, systemImage: item.symbol).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Rendered view, source code, or both")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Bigger text") { settings.bumpPreviewFont(1) }
                Button("Smaller text") { settings.bumpPreviewFont(-1) }
                Button("Actual size") { settings.resetPreviewFont() }
                Divider()
                Picker("Typeface", selection: $settings.previewFont) {
                    ForEach(PreviewFont.allCases) { Text($0.label).tag($0) }
                }
                Picker("Width", selection: $settings.contentWidth) {
                    Text("Narrow").tag(620.0)
                    Text("Normal").tag(760.0)
                    Text("Wide").tag(960.0)
                    Text("Full width").tag(0.0)
                }
                Divider()
                Toggle("Status bar", isOn: $settings.showStatusBar)
            } label: {
                Label("Appearance", systemImage: "textformat.size")
            }
            .help("Reading settings")
        }
    }

    // MARK: - Acciones

    private func reparse() async {
        let text = document.text
        if mode != .preview {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
        }
        let result = await Task.detached(priority: .userInitiated) {
            MarkdownParser.parse(text)
        }.value
        if Task.isCancelled { return }
        parsed = result
    }

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent
                                      ?? String(localized: "document")) + ".html"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let title = fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Document")
        let html = HTMLExporter.export(parsed, title: title)
        try? html.data(using: .utf8)?.write(to: url)
    }

    private func copyHTML() {
        let title = fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Document")
        let html = HTMLExporter.export(parsed, title: title, fragmentOnly: true)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .string)
    }

    private func revealInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

// MARK: - Barra de estado

struct StatusBar: View {
    let document: MarkdownDocument
    let parsed: MDDocument
    let mode: ViewMode
    let fileURL: URL?

    var body: some View {
        HStack(spacing: 14) {
            if let fileURL {
                Label(fileURL.deletingLastPathComponent().lastPathComponent, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(count("%@ lines", document.lineCount))
            Text(count("%@ words", document.wordCount))
            Text(count("%@ characters", document.text.count))
            if !parsed.headings.isEmpty {
                Text(count("%@ headings", parsed.headings.count))
            }
            Label(count("%@ min", document.readingMinutes), systemImage: "clock")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func count(_ key: String.LocalizationValue, _ value: Int) -> String {
        String(format: String(localized: key), value.formatted())
    }
}

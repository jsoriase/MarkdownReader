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
        .navigationTitle(fileURL?.lastPathComponent ?? "Sin título")
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
        return words == 0 ? "" : "\(words) palabras · \(document.readingMinutes) min"
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Modo", selection: $mode) {
                ForEach(ViewMode.allCases) { item in
                    Label(item.label, systemImage: item.symbol).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Vista formateada, código fuente o ambas")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Aumentar texto") { settings.bumpPreviewFont(1) }
                Button("Reducir texto") { settings.bumpPreviewFont(-1) }
                Button("Tamaño original") { settings.resetPreviewFont() }
                Divider()
                Picker("Tipografía", selection: $settings.previewFont) {
                    ForEach(PreviewFont.allCases) { Text($0.label).tag($0) }
                }
                Picker("Ancho", selection: $settings.contentWidth) {
                    Text("Estrecho").tag(620.0)
                    Text("Normal").tag(760.0)
                    Text("Ancho").tag(960.0)
                    Text("Completo").tag(0.0)
                }
                Divider()
                Toggle("Barra de estado", isOn: $settings.showStatusBar)
            } label: {
                Label("Presentación", systemImage: "textformat.size")
            }
            .help("Ajustes de lectura")
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
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "documento") + ".html"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Documento"
        let html = HTMLExporter.export(parsed, title: title)
        try? html.data(using: .utf8)?.write(to: url)
    }

    private func copyHTML() {
        let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Documento"
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
            Text("\(document.lineCount) líneas")
            Text("\(document.wordCount) palabras")
            Text("\(document.text.count) caracteres")
            if !parsed.headings.isEmpty {
                Text("\(parsed.headings.count) títulos")
            }
            Label("\(document.readingMinutes) min", systemImage: "clock")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

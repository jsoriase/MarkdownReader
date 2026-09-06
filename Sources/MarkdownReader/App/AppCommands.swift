import SwiftUI

struct AppCommands: Commands {
    @FocusedValue(\.documentActions) private var actions
    @ObservedObject private var settings = AppSettings.shared

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Usar Markdown Reader para abrir los .md") {
                DefaultApp.makeDefaultShowingResult()
            }
        }

        CommandGroup(replacing: .importExport) {
            Button("Exportar como HTML…") { actions?.exportHTML() }
                .disabled(actions == nil)
            Button("Copiar como HTML") { actions?.copyHTML() }
                .disabled(actions == nil)
            Divider()
            Button("Mostrar en el Finder") { actions?.revealInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Vista formateada") { actions?.mode.wrappedValue = .preview }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(actions == nil)
            Button("Código fuente") { actions?.mode.wrappedValue = .source }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(actions == nil)
            Button("Vista dividida") { actions?.mode.wrappedValue = .split }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(actions == nil)

            Divider()

            Button(actions?.outlineVisible.wrappedValue == true ? "Ocultar índice" : "Mostrar índice") {
                guard let actions else { return }
                actions.outlineVisible.wrappedValue.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(actions == nil)

            Toggle("Barra de estado", isOn: $settings.showStatusBar)

            Divider()

            Button("Aumentar tamaño de texto") { settings.bumpPreviewFont(1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Reducir tamaño de texto") { settings.bumpPreviewFont(-1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Tamaño de texto original") { settings.resetPreviewFont() }
                .keyboardShortcut("0", modifiers: .command)

            Divider()

            Picker("Apariencia", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
            }
        }

        CommandMenu("Editor") {
            Toggle("Números de línea", isOn: $settings.showLineNumbers)
            Toggle("Ajustar líneas", isOn: $settings.softWrap)
            Toggle("Resaltar sintaxis", isOn: $settings.highlightSource)
            Divider()
            Button("Aumentar tamaño del editor") {
                settings.editorFontSize = min(28, settings.editorFontSize + 1)
            }
            Button("Reducir tamaño del editor") {
                settings.editorFontSize = max(9, settings.editorFontSize - 1)
            }
        }
    }
}

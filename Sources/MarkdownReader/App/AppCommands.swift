import SwiftUI

struct AppCommands: Commands {
    @FocusedValue(\.documentActions) private var actions
    @ObservedObject private var settings = AppSettings.shared

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Open .md files with Markdown Reader") {
                DefaultApp.makeDefaultShowingResult()
            }
        }

        CommandGroup(replacing: .importExport) {
            Button("Export as HTML…") { actions?.exportHTML() }
                .disabled(actions == nil)
            Button("Copy as HTML") { actions?.copyHTML() }
                .disabled(actions == nil)
            Divider()
            Button("Reveal in Finder") { actions?.revealInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Rendered view") { actions?.mode.wrappedValue = .preview }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(actions == nil)
            Button("Source code") { actions?.mode.wrappedValue = .source }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(actions == nil)
            Button("Split view") { actions?.mode.wrappedValue = .split }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(actions == nil)

            Divider()

            Button(actions?.outlineVisible.wrappedValue == true ? "Hide outline" : "Show outline") {
                guard let actions else { return }
                actions.outlineVisible.wrappedValue.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(actions == nil)

            Toggle("Status bar", isOn: $settings.showStatusBar)

            Divider()

            Button("Bigger text") { settings.bumpPreviewFont(1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller text") { settings.bumpPreviewFont(-1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual text size") { settings.resetPreviewFont() }
                .keyboardShortcut("0", modifiers: .command)

            Divider()

            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
            }
        }

        CommandMenu("Editor") {
            Toggle("Line numbers", isOn: $settings.showLineNumbers)
            Toggle("Wrap lines", isOn: $settings.softWrap)
            Toggle("Syntax highlighting", isOn: $settings.highlightSource)
            Divider()
            Button("Bigger editor text") {
                settings.editorFontSize = min(28, settings.editorFontSize + 1)
            }
            Button("Smaller editor text") {
                settings.editorFontSize = max(9, settings.editorFontSize - 1)
            }
        }
    }
}

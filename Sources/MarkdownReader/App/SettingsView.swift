import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var isDefaultApp = DefaultApp.isDefault

    var body: some View {
        TabView {
            reading
                .tabItem { Label("Reading", systemImage: "doc.richtext") }
            editing
                .tabItem { Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right") }
        }
        .frame(width: 470, height: 500)
    }

    private var reading: some View {
        Form {
            Section {
                Picker("Typeface:", selection: $settings.previewFont) {
                    ForEach(PreviewFont.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Slider(value: $settings.previewFontSize, in: 11...28, step: 1) {
                        Text("Size:")
                    }
                    Text("\(Int(settings.previewFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Picker("Text width:", selection: $settings.contentWidth) {
                    Text("Narrow (620)").tag(620.0)
                    Text("Normal (760)").tag(760.0)
                    Text("Wide (960)").tag(960.0)
                    Text("Fill the window").tag(0.0)
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDefaultApp
                             ? "Markdown Reader opens .md files"
                             : "Another app opens .md files")
                        Text("Applies when you double-click a file in the Finder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Use this app") {
                        DefaultApp.makeDefault { _ in isDefaultApp = DefaultApp.isDefault }
                    }
                    .disabled(isDefaultApp)
                }
            }

            Section {
                Picker("Appearance:", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                Picker("Open documents in:", selection: $settings.defaultMode) {
                    ForEach(ViewMode.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Show status bar", isOn: $settings.showStatusBar)
            }

            Section {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sampleText)
                    .font(.system(size: settings.previewFontSize, design: settings.previewFont.design))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private var editing: some View {
        Form {
            Section {
                HStack {
                    Slider(value: $settings.editorFontSize, in: 9...24, step: 1) {
                        Text("Size:")
                    }
                    Text("\(Int(settings.editorFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Toggle("Line numbers", isOn: $settings.showLineNumbers)
                Toggle("Wrap long lines", isOn: $settings.softWrap)
                Toggle("Highlight Markdown syntax", isOn: $settings.highlightSource)
            } footer: {
                Text("Smart quotes and other automatic substitutions are always off, so the Markdown is never altered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private let sampleText = String(localized: "The quick brown fox jumps over the lazy dog.")
}

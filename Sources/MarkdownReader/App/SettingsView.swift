import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var isDefaultApp = DefaultApp.isDefault

    var body: some View {
        TabView {
            reading
                .tabItem { Label("Lectura", systemImage: "doc.richtext") }
            editing
                .tabItem { Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right") }
        }
        .frame(width: 460)
    }

    private var reading: some View {
        Form {
            Section {
                Picker("Tipografía:", selection: $settings.previewFont) {
                    ForEach(PreviewFont.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Slider(value: $settings.previewFontSize, in: 11...28, step: 1) {
                        Text("Tamaño:")
                    }
                    Text("\(Int(settings.previewFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Picker("Ancho del texto:", selection: $settings.contentWidth) {
                    Text("Estrecho (620)").tag(620.0)
                    Text("Normal (760)").tag(760.0)
                    Text("Ancho (960)").tag(960.0)
                    Text("Ocupar la ventana").tag(0.0)
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDefaultApp
                             ? "Markdown Reader abre los ficheros .md"
                             : "Otra app abre los ficheros .md")
                        Text("Afecta al doble clic en el Finder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Usar esta app") {
                        DefaultApp.makeDefault { _ in isDefaultApp = DefaultApp.isDefault }
                    }
                    .disabled(isDefaultApp)
                }
            }

            Section {
                Picker("Apariencia:", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                Picker("Al abrir un documento:", selection: $settings.defaultMode) {
                    ForEach(ViewMode.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Mostrar barra de estado", isOn: $settings.showStatusBar)
            }

            Section {
                Text("Vista previa")
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
                        Text("Tamaño:")
                    }
                    Text("\(Int(settings.editorFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Toggle("Números de línea", isOn: $settings.showLineNumbers)
                Toggle("Ajustar líneas largas", isOn: $settings.softWrap)
                Toggle("Resaltar la sintaxis Markdown", isOn: $settings.highlightSource)
            } footer: {
                Text("Las comillas tipográficas y las sustituciones automáticas están siempre desactivadas para no alterar el Markdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private let sampleText = "El zorro marrón salta sobre el perro perezoso."
}

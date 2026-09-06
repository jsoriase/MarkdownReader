import AppKit
import UniformTypeIdentifiers

/// Gestiona el registro de la app como visor por defecto de los ficheros
/// Markdown del usuario.
enum DefaultApp {

    static let types: [UTType] = [.markdown]

    static var isDefault: Bool {
        guard let current = NSWorkspace.shared.urlForApplication(toOpen: .markdown) else { return false }
        return current.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    static func makeDefault(completion: @escaping (Error?) -> Void) {
        let bundle = Bundle.main.bundleURL
        var pending = types.count
        var failure: Error?

        for type in types {
            NSWorkspace.shared.setDefaultApplication(at: bundle, toOpen: type) { error in
                if let error { failure = error }
                pending -= 1
                if pending == 0 {
                    DispatchQueue.main.async { completion(failure) }
                }
            }
        }
    }

    /// Muestra el resultado en un aviso, para usar desde el menú.
    static func makeDefaultShowingResult() {
        makeDefault { error in
            let alert = NSAlert()
            if let error {
                alert.alertStyle = .warning
                alert.messageText = String(localized: "Could not change the default app")
                alert.informativeText = error.localizedDescription
            } else {
                alert.alertStyle = .informational
                alert.messageText = String(localized: "Markdown Reader is now the default app")
                alert.informativeText = String(localized: "Double-clicking a .md file will open it in Markdown Reader.")
            }
            alert.runModal()
        }
    }
}

import SwiftUI

/// Renders the document: vertical scrolling with a capped column width,
/// anchors for the outline, and link handling.
struct MarkdownPreview: View {
    let document: MDDocument
    let theme: MarkdownTheme
    var baseURL: URL?
    var onToggleTask: ((Int, Bool) -> Void)?
    @Binding var scrollTarget: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        let context = RenderContext(theme: theme,
                                    links: document.linkDefinitions,
                                    baseURL: baseURL?.deletingLastPathComponent(),
                                    onToggleTask: onToggleTask)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.blockSpacing) {
                    if document.blocks.isEmpty {
                        EmptyDocumentHint(theme: theme)
                    } else {
                        ForEach(document.blocks) { block in
                            BlockView(block: block, context: context)
                        }
                    }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 28)
                .frame(maxWidth: theme.maxWidth > 0 ? CGFloat(theme.maxWidth) : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                DispatchQueue.main.async { scrollTarget = nil }
            }
        }
        .environment(\.openURL, OpenURLAction { url in handle(url) })
    }

    private func handle(_ url: URL) -> OpenURLAction.Result {
        // Internal anchor (#heading)
        if let fragment = url.fragment, url.host == nil,
           url.path.isEmpty || url.absoluteString.hasPrefix("#") {
            let anchor = fragment.lowercased()
            if document.headings.contains(where: { $0.id == anchor }) {
                scrollTarget = anchor
                return .handled
            }
            if let match = document.headings.first(where: {
                $0.plain.lowercased().replacingOccurrences(of: " ", with: "-") == anchor
            }) {
                scrollTarget = match.id
                return .handled
            }
            return .handled
        }

        if let scheme = url.scheme, scheme != "file" {
            return .systemAction
        }

        // Relative or absolute file system path
        guard let base = baseURL?.deletingLastPathComponent() else { return .systemAction }
        let path = url.isFileURL ? url.path : (url.relativePath.removingPercentEncoding ?? url.relativePath)
        guard !path.isEmpty else { return .handled }
        let target = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL

        guard FileManager.default.fileExists(atPath: target.path) else { return .handled }
        NSDocumentController.shared.openDocument(withContentsOf: target, display: true) { _, _, _ in }
        return .handled
    }
}

struct EmptyDocumentHint: View {
    let theme: MarkdownTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("Empty document")
                .font(.system(size: theme.baseSize * 1.2, weight: .semibold))
            Text("Switch to the source view (⌘2) to start writing.")
                .font(theme.smallFont)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

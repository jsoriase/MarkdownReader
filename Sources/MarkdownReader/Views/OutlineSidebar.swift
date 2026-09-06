import SwiftUI

/// The document's heading outline.
struct OutlineSidebar: View {
    let headings: [MDHeading]
    var onSelect: (MDHeading) -> Void

    @State private var filter = ""

    private var filtered: [MDHeading] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return headings }
        return headings.filter { $0.plain.lowercased().contains(query) }
    }

    private var minLevel: Int {
        headings.map(\.level).min() ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if headings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.indent")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No headings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { heading in
                        Button {
                            onSelect(heading)
                        } label: {
                            Text(heading.plain.isEmpty ? "—" : heading.plain)
                                .font(.system(size: heading.level <= minLevel ? 12.5 : 12,
                                              weight: heading.level <= minLevel ? .semibold : .regular))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, CGFloat(max(0, heading.level - minLevel)) * 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $filter, placement: .sidebar, prompt: Text("Filter headings"))
            }
        }
        .navigationTitle("Outline")
    }
}

import SwiftUI

struct PaneView: View {
    @ObservedObject var model: PaneModel
    let isActive: Bool
    let onActivate: () -> Void
    let onOpen: (FileEntry) -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            list
            Divider().opacity(0.3)
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor : Color.white.opacity(0.08),
                        lineWidth: isActive ? 1.5 : 1)
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(model.directory.path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
                .foregroundStyle(.secondary)
            Spacer()
            Text(sortLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var sortLabel: String {
        let key: String
        switch model.sortKey {
        case .name: key = "name"
        case .size: key = "size"
        case .date: key = "date"
        }
        return "\(key) \(model.sortAscending ? "↑" : "↓")"
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.entries) { entry in
                        row(entry)
                            .id(entry.url)
                    }
                }
            }
            .onChange(of: model.cursor) { _, newValue in
                if let u = newValue { withAnimation(.linear(duration: 0.05)) { proxy.scrollTo(u, anchor: .center) } }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: FileEntry) -> some View {
        let isCursor = (model.cursor == entry.url) && isActive
        let isSelected = model.selection.contains(entry.url)

        HStack(spacing: 8) {
            Image(systemName: iconName(for: entry))
                .foregroundStyle(entry.isParent ? Color.secondary
                                                : (entry.isDirectory ? Color.accentColor : Color.secondary))
                .frame(width: 16)
            Text(entry.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Text(entry.isParent ? "" : (entry.isDirectory ? "—" : byteString(entry.size)))
                .foregroundStyle(.secondary)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
            Text(entry.isParent ? "" : dateFormatter.string(from: entry.modified))
                .foregroundStyle(.secondary)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .font(.system(size: 12))
        .foregroundStyle(isSelected ? Color.yellow : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isCursor ? Color.accentColor.opacity(0.25) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen(entry) }
        .onTapGesture { onActivate(); model.cursor = entry.url }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(model.entries.filter { !$0.isParent }.count) items")
            if !model.selection.isEmpty {
                Text("·")
                Text("\(model.selection.count) selected")
                    .foregroundStyle(Color.yellow)
            }
            Spacer()
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func byteString(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }

    private func iconName(for entry: FileEntry) -> String {
        if entry.isParent { return "arrow.turn.left.up" }
        if entry.isAlias || entry.isSymlink {
            return entry.isDirectory ? "folder.fill.badge.questionmark" : "arrowshape.turn.up.right"
        }
        return entry.isDirectory ? "folder.fill" : "doc"
    }
}

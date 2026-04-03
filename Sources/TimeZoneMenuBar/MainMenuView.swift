import AppKit
import SwiftUI

private enum EditorMode: Identifiable {
    case add
    case edit(ClockEntry)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let entry):
            return entry.id.uuidString
        }
    }

    var entry: ClockEntry? {
        switch self {
        case .add:
            return nil
        case .edit(let entry):
            return entry
        }
    }

    var title: String {
        switch self {
        case .add:
            return "Add Person"
        case .edit:
            return "Edit Person"
        }
    }
}

struct MainMenuView: View {
    @ObservedObject var store: TimeZoneStore
    let preferredWidth: CGFloat
    let fillsWindow: Bool
    let showsQuitButton: Bool
    let onOpenApp: (() -> Void)?

    @State private var editorMode: EditorMode?

    private var isCompact: Bool {
        !fillsWindow
    }

    init(
        store: TimeZoneStore,
        preferredWidth: CGFloat = 360,
        fillsWindow: Bool = false,
        showsQuitButton: Bool = true,
        onOpenApp: (() -> Void)? = nil
    ) {
        self.store = store
        self.preferredWidth = preferredWidth
        self.fillsWindow = fillsWindow
        self.showsQuitButton = showsQuitButton
        self.onOpenApp = onOpenApp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
            header

            if store.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.entries) { entry in
                            ClockRow(
                                entry: entry,
                                compact: isCompact,
                                onEdit: { editorMode = .edit(entry) },
                                onDelete: { store.delete(entry) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: fillsWindow ? .infinity : 280)
            }

            footer
        }
        .padding(fillsWindow ? 20 : 12)
        .frame(
            minWidth: preferredWidth,
            idealWidth: preferredWidth,
            maxWidth: fillsWindow ? .infinity : preferredWidth,
            maxHeight: fillsWindow ? .infinity : nil,
            alignment: .topLeading
        )
        .sheet(item: $editorMode) { mode in
            EntryEditorView(
                title: mode.title,
                store: store,
                existingEntry: mode.entry
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Colleague Clock")
                .font((isCompact ? Font.title3 : .title2).weight(.semibold))

            Text("See what time it is for the people you work with.")
                .font(isCompact ? .caption : .subheadline)
                .foregroundStyle(.secondary)

            Text("Bundled time zone data: \(TimeZoneCatalog.dataVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No time zones added yet.")
                .font(isCompact ? .subheadline.weight(.semibold) : .headline)

            Text("Add a person, choose their time zone, and their local time will appear here.")
                .font(isCompact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(isCompact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        HStack {
            if let onOpenApp {
                Button("Open App") {
                    onOpenApp()
                }
            }

            Button("Add Person") {
                editorMode = .add
            }
            .keyboardShortcut(.defaultAction)

            Spacer()

            if showsQuitButton {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

private struct ClockRow: View {
    let entry: ClockEntry
    let compact: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(alignment: .top, spacing: compact ? 10 : 12) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text(entry.name)
                        .font((compact ? Font.headline : .title3).weight(.semibold))
                        .lineLimit(1)

                    Text(entry.zoneLabel(for: context.date, compact: compact))
                        .font(compact ? .caption : .caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.timeLabel(for: context.date))
                        .font(.system(compact ? .subheadline : .headline, design: .rounded).weight(.semibold))
                        .monospacedDigit()

                    Text(entry.dateLabel(for: context.date))
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: compact ? 4 : 6) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
            .padding(compact ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

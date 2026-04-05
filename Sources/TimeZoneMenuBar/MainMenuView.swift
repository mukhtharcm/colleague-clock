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
        Group {
            if fillsWindow {
                windowContent
            } else {
                compactContent
            }
        }
        .sheet(item: $editorMode) { mode in
            EntryEditorView(
                title: mode.title,
                store: store,
                existingEntry: mode.entry
            )
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.entries.isEmpty {
                compactEmptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.entries) { entry in
                            CompactClockRow(
                                entry: entry
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 280)
            }

            compactFooter
        }
        .padding(12)
        .frame(width: preferredWidth, alignment: .topLeading)
    }

    private var windowContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage People")
                        .font(.headline)

                    Text("Reorder by dragging rows. Changes save automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Add Person") {
                    editorMode = .add
                }
                .keyboardShortcut(.defaultAction)
            }

            if store.entries.isEmpty {
                windowEmptyState
            } else {
                List {
                    ForEach(store.entries) { entry in
                        WindowClockRow(
                            entry: entry,
                            onEdit: { editorMode = .edit(entry) },
                            onDelete: { store.delete(entry) }
                        )
                    }
                    .onMove(perform: store.moveEntries)
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(
            minWidth: preferredWidth,
            idealWidth: preferredWidth,
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
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

    private var compactEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No time zones added yet.")
                .font(.subheadline.weight(.semibold))

            Text("Add a person and their local time will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var windowEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No people added yet.")
                .font(.headline)

            Text("Add someone to start tracking their local time here and in the menu bar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add First Person") {
                editorMode = .add
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var compactFooter: some View {
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

private struct CompactClockRow: View {
    let entry: ClockEntry

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text(entry.zoneLabel(for: context.date, compact: true))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.timeLabel(for: context.date))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()

                    Text(entry.dateLabel(for: context.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct WindowClockRow: View {
    let entry: ClockEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.headline.weight(.semibold))

                    Text(entry.zoneLabel(for: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(entry.timeLabel(for: context.date))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()

                    Text(entry.dateLabel(for: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Edit", action: onEdit)

                    Button("Delete", role: .destructive, action: onDelete)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            .contextMenu {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }
}

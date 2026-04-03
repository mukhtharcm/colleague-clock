import SwiftUI

struct EntryEditorView: View {
    let title: String
    @ObservedObject var store: TimeZoneStore
    let existingEntry: ClockEntry?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var name: String
    @State private var searchText: String
    @State private var selectedTimeZoneIdentifier: String

    private enum Field {
        case name
        case search
    }

    init(title: String, store: TimeZoneStore, existingEntry: ClockEntry?) {
        self.title = title
        self.store = store
        self.existingEntry = existingEntry

        _name = State(initialValue: existingEntry?.name ?? "")
        _searchText = State(initialValue: "")
        _selectedTimeZoneIdentifier = State(
            initialValue: TimeZoneCatalog.canonicalIdentifier(
                for: existingEntry?.timeZoneIdentifier ?? TimeZone.current.identifier
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)

            TextField("Search city, country, or time zone", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .search)

            Text("Country search is supported. For example, searching for India or United States will show the matching time zones.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(filteredChoices) { choice in
                Button {
                    selectedTimeZoneIdentifier = choice.identifier
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: choice.identifier == selectedTimeZoneIdentifier ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(choice.identifier == selectedTimeZoneIdentifier ? Color.accentColor : Color.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(choice.cityName)
                                .foregroundStyle(.primary)

                            Text(choice.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 260)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save") {
                    store.save(
                        name: name,
                        timeZoneIdentifier: selectedTimeZoneIdentifier,
                        editing: existingEntry
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear {
            focusedField = .name
        }
    }

    private var filteredChoices: [TimeZoneChoice] {
        TimeZoneCatalog.search(matching: searchText)
    }
}

import SwiftUI
import AppKit

struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let service: ServiceDefinition?
    let onSave: (ServiceDefinition) -> Void

    @State private var id: UUID
    @State private var name: String
    @State private var kind: ServiceKind
    @State private var directory: String
    @State private var command: String
    @State private var port: String
    @State private var group: String

    init(service: ServiceDefinition?, onSave: @escaping (ServiceDefinition) -> Void) {
        self.service = service
        self.onSave = onSave
        _id = State(initialValue: service?.id ?? UUID())
        _name = State(initialValue: service?.name ?? "")
        _kind = State(initialValue: service?.kind ?? .command)
        _directory = State(initialValue: service?.workingDirectory ?? "")
        _command = State(initialValue: service?.command ?? "")
        _port = State(initialValue: service?.port.map(String.init) ?? "")
        _group = State(initialValue: service?.group ?? "")
    }

    private var parsedPort: Int? { Int(port) }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (port.isEmpty || (parsedPort.map { (1...65535).contains($0) } ?? false))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(service == nil ? "Add Service" : "Edit Service").font(.title2).bold()
            Form {
                TextField("Name", text: $name)
                Picker("Execution Type", selection: $kind) {
                    ForEach(ServiceKind.allCases) { Text($0.rawValue).tag($0) }
                }
                HStack {
                    TextField("Working Directory", text: $directory)
                    Button("Browse…") { browseDirectory() }
                }
                TextField(kind == .command ? "Start Command" : "Compose Service Name", text: $command)
                TextField("Port (optional)", text: $port)
                TextField("Group (optional)", text: $group)
            }
            Text(kind == .command ? "Example: npm run dev" : "Example: db · Uses docker compose in the selected directory")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(ServiceDefinition(id: id, name: name, kind: kind, workingDirectory: directory, command: command, port: parsedPort, group: group))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { directory = url.path }
    }
}

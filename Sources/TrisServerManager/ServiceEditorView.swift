import SwiftUI
import WakTrainerDesignSystem
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
    @State private var healthCheckPath: String
    @State private var suggestions: [LocalCommandSuggestion] = []
    @State private var selectedPresetID = ""

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
        _healthCheckPath = State(initialValue: service?.healthCheckPath ?? "")
    }

    private var parsedPort: Int? { Int(port) }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (kind == .homebrewPostgres || !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (kind == .homebrewPostgres ? (parsedPort.map { (1...65535).contains($0) } ?? false) : (port.isEmpty || (parsedPort.map { (1...65535).contains($0) } ?? false))) &&
        (healthCheckPath.isEmpty || (kind == .command && parsedPort != nil && healthCheckPath.hasPrefix("/") && !healthCheckPath.hasPrefix("//") && !healthCheckPath.contains("?") && !healthCheckPath.contains("#")))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.large) {
            Text(service == nil ? "Add Service" : "Edit Service")
                .font(WakTypography.screenTitle)
                .foregroundStyle(WakColor.textPrimary)
            Form {
                if service == nil {
                    Picker("Quick Setup", selection: $selectedPresetID) {
                        Text("Custom Service").tag("")
                        ForEach(DevelopmentServicePreset.known) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .onChange(of: selectedPresetID) { _, newValue in
                        guard let preset = DevelopmentServicePreset.known.first(where: { $0.id == newValue }) else { return }
                        name = preset.name
                        kind = .command
                        command = preset.command
                        port = preset.port.map(String.init) ?? ""
                        group = preset.group
                        healthCheckPath = preset.name == "TrisAuthenticationServer" ? "/hello" : (preset.name == "WakTrainerServer" ? "/health" : "")
                        directory = ""
                        suggestions = []
                    }
                    if let preset = DevelopmentServicePreset.known.first(where: { $0.id == selectedPresetID }) {
                        Text(preset.hint).font(.caption).foregroundStyle(.secondary)
                    }
                }
                TextField("Name", text: $name)
                Picker("Execution Type", selection: $kind) {
                    ForEach(ServiceKind.allCases) { Text($0.rawValue).tag($0) }
                }
                HStack {
                    TextField("Working Directory", text: $directory)
                    Button("Browse…") { browseDirectory() }
                }
                if kind == .command {
                    Button("Detect Project Commands") {
                        suggestions = LocalProjectDetector.suggestions(in: URL(fileURLWithPath: directory))
                    }
                    .disabled(directory.isEmpty)
                    if suggestions.isEmpty {
                        Text("Select a project folder, then detect available commands.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(suggestions) { suggestion in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title).font(.subheadline)
                                    Text(suggestion.command).font(.system(.caption, design: .monospaced))
                                    Text(suggestion.explanation).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Use") { command = suggestion.command }
                            }
                        }
                    }
                }
                if kind != .homebrewPostgres { TextField(kind == .command ? "Start Command" : "Compose Service Name", text: $command) }
                TextField(kind == .homebrewPostgres ? "PostgreSQL Port" : "Port (optional)", text: $port)
                if kind == .command {
                    TextField("HTTP Health Path (optional, e.g. /health)", text: $healthCheckPath)
                }
                TextField("Group (optional)", text: $group)
            }
            Text(kind == .homebrewPostgres ? "Select an existing initialized PostgreSQL 16 data directory containing PG_VERSION. No database is installed or migrated automatically." : (kind == .command ? "Review the command and select the correct local project folder before saving." : "Example: db · Uses docker compose in the selected directory"))
                .font(WakTypography.caption).foregroundStyle(WakColor.textSecondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(ServiceDefinition(id: id, name: name, kind: kind, workingDirectory: directory, command: kind == .homebrewPostgres ? "" : command, port: parsedPort, group: group, healthCheckPath: kind == .command ? healthCheckPath : nil))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(WakColor.background)
        .tint(WakColor.primary)
        .preferredColorScheme(.dark)
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            directory = url.path
            suggestions = LocalProjectDetector.suggestions(in: url)
        }
    }
}

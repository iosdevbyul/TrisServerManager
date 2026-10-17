import SwiftUI
import AppKit

struct ComposeImportView: View {
    @Environment(\.dismiss) private var dismiss
    let existingServices: [ServiceDefinition]
    let onImport: ([ServiceDefinition]) -> Void

    @State private var directory = ""
    @State private var candidates: [ComposeServiceCandidate] = []
    @State private var selectedNames: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var importableNames: Set<String> {
        let existing = Set(existingServices.filter { $0.kind == .dockerCompose && $0.workingDirectory == directory }.map(\.command))
        return Set(candidates.map(\.name)).subtracting(existing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Docker Compose Services").font(.title2).bold()
            Text("Select a project directory containing a Compose file. This only reads configuration; it does not start or stop containers.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("Compose project directory", text: $directory)
                Button("Browse…") { browse() }
                Button("Discover") { Task { await discover() } }
                    .disabled(directory.isEmpty || isLoading)
            }
            if isLoading { ProgressView("Discovering services…") }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
            }
            List {
                ForEach(candidates) { candidate in
                    let available = importableNames.contains(candidate.name)
                    Toggle(candidate.name + (available ? "" : " (already registered)"), isOn: Binding(
                        get: { selectedNames.contains(candidate.name) },
                        set: { chosen in
                            if chosen { selectedNames.insert(candidate.name) }
                            else { selectedNames.remove(candidate.name) }
                        }
                    ))
                    .disabled(!available)
                }
            }
            .frame(minHeight: 200)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Import Selected") {
                    let entries = selectedNames.sorted().map {
                        ServiceDefinition(name: $0, kind: .dockerCompose, workingDirectory: directory, command: $0, port: nil, group: URL(fileURLWithPath: directory).lastPathComponent)
                    }
                    onImport(entries)
                    dismiss()
                }
                .disabled(selectedNames.intersection(importableNames).isEmpty || isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 630, height: 490)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            directory = url.path
            candidates = []
            selectedNames = []
        }
    }

    private func discover() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            candidates = try await ComposeServiceDiscovery.discover(in: URL(fileURLWithPath: directory))
            selectedNames = importableNames
        } catch {
            candidates = []
            selectedNames = []
            errorMessage = error.localizedDescription
        }
    }
}

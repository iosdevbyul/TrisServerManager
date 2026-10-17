import SwiftUI
import AppKit
import WakTrainerDesignSystem

struct ProjectDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    let existingServices: [ServiceDefinition]
    let onImport: ([ServiceDefinition]) -> Void

    @State private var root = ""
    @State private var found: [DiscoveredService] = []
    @State private var selected: Set<String> = []
    @State private var scanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.regular) {
            Text("Scan Development Projects")
                .font(WakTypography.screenTitle)
                .foregroundStyle(WakColor.textPrimary)
            Text("Scan a parent folder for local projects. Nothing is executed. Review detected commands and ports before starting services.")
                .foregroundStyle(WakColor.textSecondary)
            HStack {
                TextField("Parent folder", text: $root)
                Button("Browse…") { browse() }
                Button("Scan") { scan() }.disabled(root.isEmpty || scanning)
            }
            if scanning { ProgressView("Scanning projects…") }
            List {
                ForEach(found) { entry in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { selected.contains(entry.id) },
                            set: { enabled in
                                if enabled { selected.insert(entry.id) }
                                else { selected.remove(entry.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.definition.name).font(.headline)
                                Text(entry.definition.workingDirectory)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                Text(entry.note).font(.caption).foregroundStyle(.secondary)
                                if entry.isReady {
                                    Text(entry.definition.command).font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                        .disabled(!entry.isReady)
                    }
                }
            }
            .frame(minHeight: 240)
            if found.isEmpty {
                Text("No candidates yet. Select a parent directory and scan.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Only entries with a suggested launch command can be imported. Uncertain entries require manual Add Service.")
                .font(.caption).foregroundStyle(WakColor.textSecondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                WakPrimaryButton("Import Selected", isEnabled: !selected.isEmpty) {
                    let entries = found.filter { selected.contains($0.id) && $0.isReady }.map(\.definition)
                    onImport(entries)
                    dismiss()
                }
            }
        }
        .padding(WakSpacing.large)
        .frame(width: 750, height: 590)
        .background(WakColor.background)
        .tint(WakColor.primary)
        .preferredColorScheme(.dark)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            root = url.path
            found = []
            selected = []
        }
    }

    private func scan() {
        scanning = true
        found = ProjectDiscovery.scan(root: URL(fileURLWithPath: root), existing: existingServices)
        selected = Set(found.filter(\.isReady).map(\.id))
        scanning = false
    }
}

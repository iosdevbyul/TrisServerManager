import SwiftUI
import WakTrainerDesignSystem

struct DashboardView: View {
    @Bindable var store: ServiceStore
    @Bindable var runtime: ServiceRuntime
    @State private var selectedID: UUID?
    @State private var editing: ServiceDefinition?
    @State private var showEditor = false
    @State private var pendingDeletion: ServiceDefinition?

    private var selected: ServiceDefinition? {
        store.services.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section("SERVICES") {
                    ForEach(store.services) { service in
                        Label(service.name, systemImage: service.kind == .dockerCompose ? "shippingbox" : "terminal")
                            .tag(service.id)
                            .contextMenu {
                                Button("Edit") { openEditor(service) }
                                Button("Remove", role: .destructive) { pendingDeletion = service }
                                    .disabled(runtime.status(for: service) == .running)
                            }
                    }
                }
            }
            .navigationTitle("Servers")
            .scrollContentBackground(.hidden)
            .background(WakColor.background)
            .toolbar {
                ToolbarItem {
                    Button { openEditor(nil) } label: { Image(systemName: "plus") }
                        .help("Add service")
                }
            }
        } detail: {
            VStack(alignment: .leading, spacing: WakSpacing.large) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("TrisServerManager")
                            .font(WakTypography.screenTitle)
                            .foregroundStyle(WakColor.textPrimary)
                        Text("Manage your local development services")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Start All") { Task { await runtime.startAll(store.services) } }
                        .disabled(store.services.isEmpty)
                    Button("Stop All") { Task { await runtime.stopAll(store.services) } }
                        .disabled(store.services.isEmpty)
                }
                Divider()
                if let selected {
                    HStack {
                        Label(selected.name, systemImage: "server.rack")
                            .font(.title2).bold()
                        Spacer()
                        Button("Edit") { openEditor(selected) }
                        Button("Remove", role: .destructive) { pendingDeletion = selected }
                            .disabled(runtime.status(for: selected) == .running)
                        Button("Start") { Task { await runtime.start(selected) } }
                            .disabled(runtime.status(for: selected) == .running || runtime.status(for: selected) == .starting)
                        Button("Stop") { Task { await runtime.stop(selected) } }
                            .disabled(runtime.status(for: selected) == .stopped || runtime.status(for: selected) == .stopping)
                        Button("Refresh") { Task { await runtime.refresh(selected) } }
                    }
                    WakCard {
                        VStack(alignment: .leading, spacing: WakSpacing.large) {
                    LabeledContent("Type", value: selected.kind.rawValue)
                    LabeledContent("Group", value: selected.group.isEmpty ? "Ungrouped" : selected.group)
                    LabeledContent("Directory", value: selected.workingDirectory)
                    LabeledContent(selected.kind == .command ? "Command" : "Compose service", value: selected.command)
                    if let port = selected.port { LabeledContent("Port", value: String(port)) }
                        }
                    }
                    LabeledContent("Status", value: runtime.status(for: selected).rawValue)
                    Text("Logs").font(.headline)
                    ScrollView {
                        Text(runtime.log(for: selected.id))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 260)
                    .padding(12)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ContentUnavailableView("Choose a Service", systemImage: "server.rack", description: Text("Select a service or use + to register one."))
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WakColor.background)
        }
        .task { await runtime.refreshAll(store.services) }
        .sheet(isPresented: $showEditor) {
            ServiceEditorView(service: editing) { service in
                if editing == nil { store.add(service) } else { store.update(service) }
                selectedID = service.id
            }
        }
        .confirmationDialog("Remove this service?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Remove Registration", role: .destructive) {
                guard let service = pendingDeletion else { return }
                guard runtime.status(for: service) != .running else { return }
                store.delete(service.id)
                runtime.forget(service.id)
                if selectedID == service.id { selectedID = nil }
                pendingDeletion = nil
            }
        } message: {
            Text("Only the entry in TrisServerManager is removed. No processes, containers, or data will be deleted.")
        }
        .alert("Service Execution Error", isPresented: Binding(
            get: { runtime.errorMessage != nil }, set: { if !$0 { runtime.errorMessage = nil } }
        )) { Button("OK") { runtime.errorMessage = nil } } message: {
            Text(runtime.errorMessage ?? "Unknown error")
        }
        .alert("Service Configuration Error", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private func openEditor(_ service: ServiceDefinition?) {
        editing = service
        showEditor = true
    }
}

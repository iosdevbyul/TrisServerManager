import SwiftUI
import WakTrainerDesignSystem

struct DashboardView: View {
    @Bindable var store: ServiceStore
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
                    Button("Start All") {}.disabled(true)
                    Button("Stop All") {}.disabled(true)
                }
                Divider()
                if let selected {
                    HStack {
                        Label(selected.name, systemImage: "server.rack")
                            .font(.title2).bold()
                        Spacer()
                        Button("Edit") { openEditor(selected) }
                        Button("Remove", role: .destructive) { pendingDeletion = selected }
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
                    Label("Not monitored yet · Execution available in Phase 2", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Choose a Service", systemImage: "server.rack", description: Text("Select a service or use + to register one."))
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WakColor.background)
        }
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
                store.delete(service.id)
                if selectedID == service.id { selectedID = nil }
                pendingDeletion = nil
            }
        } message: {
            Text("Only the entry in TrisServerManager is removed. No processes, containers, or data will be deleted.")
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

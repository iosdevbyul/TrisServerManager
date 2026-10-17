import SwiftUI
import WakTrainerDesignSystem

struct DashboardView: View {
    @Bindable var store: ServiceStore
    @Bindable var runtime: ServiceRuntime
    @State private var selectedID: UUID?
    @State private var editing: ServiceDefinition?
    @State private var showEditor = false
    @State private var showComposeImport = false
    @State private var pendingDeletion: ServiceDefinition?
    @State private var autoRefreshEnabled = true
    @State private var lastRefreshed: Date?

    private var selected: ServiceDefinition? {
        store.services.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section("SERVICES") {
                    ForEach(store.services) { service in
                        HStack {
                            Label(service.name, systemImage: service.kind == .dockerCompose ? "shippingbox" : "terminal")
                            Spacer()
                            Text(runtime.status(for: service).rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(service.id)
                            .contextMenu {
                                Button("Edit") { openEditor(service) }
                                    .disabled(runtime.status(for: service) == .running || runtime.status(for: service) == .starting || runtime.status(for: service) == .stopping)
                                Button("Remove", role: .destructive) { pendingDeletion = service }
                                    .disabled(runtime.status(for: service) == .running || runtime.status(for: service) == .starting || runtime.status(for: service) == .stopping)
                            }
                    }
                }
            }
            .navigationTitle("Servers")
            .scrollContentBackground(.hidden)
            .background(WakColor.background)
            .toolbar {
                ToolbarItemGroup {
                    Button { showComposeImport = true } label: { Image(systemName: "shippingbox.and.arrow.backward") }
                        .help("Import Docker Compose services")
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
                    Button("Refresh All") { Task { await refreshMonitoringSnapshot() } }
                    Toggle("Auto Refresh", isOn: $autoRefreshEnabled)
                        .toggleStyle(.checkbox)
                        .fixedSize()
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
                        if selected.kind == .dockerCompose {
                            Button("Load Logs") { Task { await runtime.loadDockerLogs(selected) } }
                        }
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
                    HStack {
                        Text("Logs").font(.headline)
                        Spacer()
                        if let lastRefreshed {
                            Text("Last checked \(lastRefreshed.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        .task(id: autoRefreshEnabled) {
            await refreshMonitoringSnapshot()
            guard autoRefreshEnabled else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) }
                catch { break }
                guard !Task.isCancelled else { break }
                await refreshMonitoringSnapshot()
            }
        }
        .sheet(isPresented: $showComposeImport) {
            ComposeImportView(existingServices: store.services) { imported in
                for service in imported { store.add(service) }
                if let first = imported.first { selectedID = first.id }
            }
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
                guard ![ServiceRuntimeStatus.running, .starting, .stopping].contains(runtime.status(for: service)) else { return }
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

    private func refreshMonitoringSnapshot() async {
        await runtime.refreshAll(store.services)
        if let selected, selected.kind == .dockerCompose {
            await runtime.loadDockerLogs(selected)
        }
        lastRefreshed = .now
    }

    private func openEditor(_ service: ServiceDefinition?) {
        editing = service
        showEditor = true
    }
}

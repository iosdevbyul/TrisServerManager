import SwiftUI
import WakTrainerDesignSystem

struct DashboardView: View {
    @Bindable var store: ServiceStore
    @Bindable var runtime: ServiceRuntime
    @State private var selectedID: UUID?
    @State private var editing: ServiceDefinition?
    @State private var showEditor = false
    @State private var showComposeImport = false
    @State private var showProjectScan = false
    @State private var pendingDeletion: ServiceDefinition?
    @State private var showRemoveAllConfirmation = false
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: WakSpacing.small) {
                    WakPrimaryButton("Scan Projects") { showProjectScan = true }
                    WakSecondaryButton("Add Service") { openEditor(nil) }
                    WakSecondaryButton("Import Docker Compose") { showComposeImport = true }
                    Button("Remove All Services", role: .destructive) {
                        showRemoveAllConfirmation = true
                    }
                    .disabled(!runtime.canRemoveRegistrations(store.services))
                    .foregroundStyle(WakColor.destructive)
                }
                .padding(WakSpacing.regular)
                .frame(maxWidth: .infinity)
                .background(WakColor.surface)
            }
            .navigationTitle("Servers")
            .scrollContentBackground(.hidden)
            .background(WakColor.background)
            .tint(WakColor.primary)
            .toolbar {
                ToolbarItemGroup {
                    Button { showProjectScan = true } label: { Image(systemName: "folder.badge.gearshape") }
                        .help("Scan development projects")
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
                        .tint(WakColor.primary)
                    Toggle("Auto Refresh", isOn: $autoRefreshEnabled)
                        .tint(WakColor.primary)
                        .toggleStyle(.checkbox)
                        .fixedSize()
                }
                Rectangle()
                    .fill(WakColor.divider)
                    .frame(height: 1)
                if let selected {
                    HStack {
                        Label(selected.name, systemImage: "server.rack")
                            .font(.title2).bold()
                        Spacer()
                        Button("Edit") { openEditor(selected) }
                        Button("Remove", role: .destructive) { pendingDeletion = selected }
                            .disabled(runtime.status(for: selected) == .running)
                        Button("Start") { Task { await runtime.start(selected) } }
                            .disabled(runtime.status(for: selected) == .running || runtime.status(for: selected) == .starting || runtime.status(for: selected) == .portInUse)
                        Button("Stop") { Task { await runtime.stop(selected) } }
                            .disabled(selected.kind == .command ? !runtime.ownsRunningProcess(selected.id) : (runtime.status(for: selected) == .stopped || runtime.status(for: selected) == .stopping))
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
                        .foregroundStyle(WakColor.textPrimary)
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
                    .background(WakColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    WakCard {
                        VStack(alignment: .leading, spacing: WakSpacing.regular) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 34))
                                .foregroundStyle(WakColor.primary)
                            Text("No Service Selected")
                                .font(WakTypography.sectionTitle)
                                .foregroundStyle(WakColor.textPrimary)
                            Text("Register a local server or import services from a Docker Compose project.")
                                .font(WakTypography.body)
                                .foregroundStyle(WakColor.textSecondary)
                            HStack {
                                WakPrimaryButton("Add Service") { openEditor(nil) }
                                WakSecondaryButton("Import Docker Compose") { showComposeImport = true }
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 52)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WakColor.background)
        }
        .tint(WakColor.primary)
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
        .sheet(isPresented: $showProjectScan) {
            ProjectDiscoveryView(existingServices: store.services) { imported in
                for service in imported { store.add(service) }
                if let first = imported.first { selectedID = first.id }
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
        .confirmationDialog("Remove all registered services?", isPresented: $showRemoveAllConfirmation, titleVisibility: .visible) {
            Button("Remove All Registrations", role: .destructive) {
                guard runtime.canRemoveRegistrations(store.services) else { return }
                let ids = store.services.map(\.id)
                store.deleteAll()
                ids.forEach { runtime.forget($0) }
                selectedID = nil
                pendingDeletion = nil
            }
        } message: {
            Text("This removes all \(store.services.count) service registrations from TrisServerManager. It does not stop servers, delete Docker containers or volumes, or remove project files. This cannot be undone.")
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

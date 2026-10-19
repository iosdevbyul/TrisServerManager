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
                    sidebarAction("Scan Projects", icon: "magnifyingglass", prominent: true) { showProjectScan = true }
                    sidebarAction("Add Service", icon: "plus") { openEditor(nil) }
                    sidebarAction("Import Docker Compose", icon: "shippingbox") { showComposeImport = true }
                    Button(role: .destructive) { showRemoveAllConfirmation = true } label: {
                        Label("Remove All", systemImage: "trash")
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!runtime.canRemoveRegistrations(store.services))
                    .padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(WakColor.surface)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 360)
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
            ScrollView {
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
                        .buttonStyle(.borderedProminent)
                        .disabled(store.services.isEmpty)
                    Button("Stop All") { Task { await runtime.stopAll(store.services) } }
                        .buttonStyle(.bordered)
                        .disabled(store.services.isEmpty)
                    Button("Refresh All") { Task { await refreshMonitoringSnapshot() } }
                        .buttonStyle(.bordered)
                        .tint(WakColor.primary)
                    Toggle("Auto Refresh", isOn: $autoRefreshEnabled)
                        .tint(WakColor.primary)
                        .toggleStyle(.checkbox)
                        .fixedSize()
                }
                Rectangle()
                    .fill(WakColor.primary.opacity(0.35))
                    .frame(height: 1)
                if let selected {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: selected.kind == .dockerCompose ? "shippingbox.fill" : "terminal.fill")
                                .font(.title3)
                                .foregroundStyle(WakColor.primary)
                                .frame(width: 40, height: 40)
                                .background(WakColor.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selected.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(WakColor.textPrimary)
                                Text(selected.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(WakColor.textSecondary)
                            }
                            Spacer()
                            Button("Edit") { openEditor(selected) }
                            Button("Remove", role: .destructive) { pendingDeletion = selected }
                                .disabled(runtime.status(for: selected) == .running)
                            Button("Start") { Task { await runtime.start(selected) } }
                                .buttonStyle(.borderedProminent)
                                .disabled(runtime.status(for: selected) == .running || runtime.status(for: selected) == .starting || runtime.status(for: selected) == .portInUse)
                            Button("Stop") { Task { await runtime.stop(selected) } }
                                .disabled(selected.kind == .command ? !runtime.ownsRunningProcess(selected.id) : (runtime.status(for: selected) == .stopped || runtime.status(for: selected) == .stopping))
                            Button("Refresh") { Task { await runtime.refresh(selected) } }
                            if selected.kind == .dockerCompose {
                                Button("Load Logs") { Task { await runtime.loadDockerLogs(selected) } }
                            }
                        }
                        Rectangle().fill(WakColor.primary.opacity(0.3)).frame(height: 1)
                        HStack(spacing: 12) {
                            detailTile("GROUP", value: selected.group.isEmpty ? "Ungrouped" : selected.group, symbol: "square.stack.3d.up")
                            detailTile("PORT", value: selected.port.map(String.init) ?? "Not set", symbol: "network")
                            if let path = selected.effectiveHealthCheckPath {
                                detailTile("HEALTH", value: path, symbol: "heart.text.square")
                            }
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            Label("WORKING DIRECTORY", systemImage: "folder")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WakColor.textSecondary)
                            Text(selected.workingDirectory)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(WakColor.textPrimary)
                                .textSelection(.enabled)
                            Divider().overlay(WakColor.divider)
                            Label(selected.kind == .command ? "START COMMAND" : "COMPOSE SERVICE", systemImage: "terminal")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WakColor.textSecondary)
                            Text(selected.command)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(WakColor.primary)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WakColor.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(18)
                    .background(WakColor.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(WakColor.primary.opacity(0.22)))
                    HStack(spacing: 10) {
                        Circle()
                            .fill(statusColor(runtime.status(for: selected)))
                            .frame(width: 9, height: 9)
                        Text(runtime.status(for: selected).rawValue)
                            .font(.headline)
                        Spacer()
                        if let port = selected.port {
                            Text("PORT \(port)")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .foregroundStyle(WakColor.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(WakColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
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
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(WakColor.divider.opacity(0.7)))
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
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 52)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WakColor.background)
            }
            .background(WakColor.background)
        }
        .tint(WakColor.primary)
        .task {
            // Recovery is a one-shot startup action, not part of periodic refresh.
            await runtime.recoverExistingServicesAtLaunch(store.services)
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

    private func detailTile(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WakColor.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WakColor.textPrimary)
                .lineLimit(1)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(WakColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sidebarAction(_ title: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(prominent ? WakColor.primary : WakColor.surfaceSecondary)
        .help(title)
    }

    private func statusColor(_ status: ServiceRuntimeStatus) -> Color {
        switch status {
        case .running: return .green
        case .starting, .stopping: return .orange
        case .failed: return .red
        case .stopped: return WakColor.textSecondary
        case .unknown, .portInUse: return .yellow
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

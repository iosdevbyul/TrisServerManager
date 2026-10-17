import SwiftUI

@main
struct TrisServerManagerApp: App {
    @State private var store = ServiceStore()
    @State private var runtime = ServiceRuntime()

    var body: some Scene {
        WindowGroup("TrisServerManager") {
            DashboardView(store: store, runtime: runtime)
                .frame(minWidth: 820, minHeight: 530)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1000, height: 650)

        MenuBarExtra("TrisServerManager", systemImage: "server.rack") {
            Text("\(store.services.count) registered services")
            Divider()
            ForEach(store.services) { service in
                Menu(service.name + " · " + runtime.status(for: service).rawValue) {
                    Button("Start") { Task { await runtime.start(service) } }
                    Button("Stop") { Task { await runtime.stop(service) } }
                    if service.kind == .dockerCompose {
                        Button("Refresh Status") { Task { await runtime.refresh(service) } }
                    }
                }
            }
            if store.services.isEmpty {
                Text("Add services from the main window")
            }
            Divider()
            Button("Start All") { Task { await runtime.startAll(store.services) } }
            Button("Stop All") { Task { await runtime.stopAll(store.services) } }
        }
    }
}

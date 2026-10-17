import SwiftUI

@main
struct TrisServerManagerApp: App {
    @State private var store = ServiceStore()

    var body: some Scene {
        WindowGroup("TrisServerManager") {
            DashboardView(store: store)
                .frame(minWidth: 820, minHeight: 530)
        }
        .defaultSize(width: 1000, height: 650)

        MenuBarExtra("TrisServerManager", systemImage: "server.rack") {
            Text("\(store.services.count) registered services")
            Divider()
            ForEach(store.services) { service in
                Label(service.name, systemImage: "circle.dotted")
            }
            if store.services.isEmpty {
                Text("Add services from the main window")
            }
            Divider()
            Text("Execution controls coming in Phase 2")
                .font(.caption)
        }
    }
}

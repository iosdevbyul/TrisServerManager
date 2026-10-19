import SwiftUI
import WakTrainerDesignSystem

struct PortConflictReviewView: View {
    let conflict: PortConflict
    let approve: (Set<String>) -> Void
    let cancel: () -> Void

    @State private var selectedIDs: Set<String>

    init(conflict: PortConflict, approve: @escaping (Set<String>) -> Void, cancel: @escaping () -> Void) {
        self.conflict = conflict
        self.approve = approve
        self.cancel = cancel
        _selectedIDs = State(initialValue: Set(conflict.targets.filter { $0.pid != nil || $0.containerID != nil }.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Port \(conflict.port) Conflict", systemImage: "exclamationmark.triangle.fill")
                .font(.title2.bold())
                .foregroundStyle(WakColor.textPrimary)
            Text("The following services are using port \(conflict.port). Select which ones to stop before starting \(conflict.service.name).")
                .foregroundStyle(WakColor.textSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(conflict.targets) { target in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(target.id) },
                            set: { checked in
                                if checked { selectedIDs.insert(target.id) }
                                else { selectedIDs.remove(target.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(target.title).font(.headline)
                                Text(target.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(target.pid == nil && target.containerID == nil)
                        .padding(12)
                        .background(WakColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Text("Only selected, verified targets will be stopped. Docker Desktop itself will not be terminated. If the port remains busy, startup will be cancelled.")
                .font(.caption)
                .foregroundStyle(WakColor.textSecondary)
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                Button("Stop Selected & Start") { approve(selectedIDs) }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIDs.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 340)
        .background(WakColor.background)
    }
}

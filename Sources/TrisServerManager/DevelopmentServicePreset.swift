import Foundation

struct DevelopmentServicePreset: Identifiable {
    let id: String
    let name: String
    let command: String
    let port: Int?
    let group: String
    let hint: String

    static let known: [DevelopmentServicePreset] = [
        .init(id: "donghak", name: "DonghakStockVision API", command: "", port: nil, group: "DonghakStockVision", hint: "Enter the verified Python API launch command and port."),
        .init(id: "marketlens", name: "TrisMarketLens", command: "npm run dev", port: nil, group: "TrisMarketLens", hint: "Review Next.js port: Docker Grafana may already occupy 3000."),
        .init(id: "waktrainer", name: "WakTrainerServer", command: "swift run WakTrainerServer serve --hostname 127.0.0.1 --port 8081", port: 8081, group: "WakTrainer", hint: "Select the Swift server repository root."),
        .init(id: "authentication", name: "TrisAuthenticationServer", command: "swift run TrisAuthenticationServer serve --hostname 127.0.0.1 --port 8080", port: 8080, group: "Authentication", hint: "Select the Swift authentication server repository root."),
        .init(id: "reward-ledger", name: "Reward Ledger Server", command: "python3 server/app.py", port: 8765, group: "TrisAdKit", hint: "Select the TrisAdKit repository root. Set REWARD_API_TOKENS_JSON to a development-only token map in the manager launch environment; never store live credentials in the repository.")
    ]

    func draft() -> ServiceDefinition {
        ServiceDefinition(name: name, kind: .command, workingDirectory: "", command: command, port: port, group: group)
    }
}

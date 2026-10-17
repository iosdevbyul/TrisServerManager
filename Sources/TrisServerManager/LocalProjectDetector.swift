import Foundation

struct LocalCommandSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let command: String
    let explanation: String
}

enum LocalProjectDetector {
    static func suggestions(in directory: URL) -> [LocalCommandSuggestion] {
        let fm = FileManager.default
        let root = directory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        var results: [LocalCommandSuggestion] = []
        if fm.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            results.append(.init(id: "swift", title: "Swift Package", command: "swift run", explanation: "Review the executable target and add any required arguments."))
        }

        let packageJSON = root.appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: packageJSON),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = object["scripts"] as? [String: Any] {
            for name in ["dev", "start"] where scripts[name] is String {
                results.append(.init(id: "npm-\(name)", title: "Node.js · \(name)", command: "npm run \(name)", explanation: "Found in package.json scripts. Confirm the configured port."))
            }
        }

        if fm.fileExists(atPath: root.appendingPathComponent("manage.py").path) {
            results.append(.init(id: "django", title: "Django", command: "python3 manage.py runserver", explanation: "Detected manage.py; verify the Python environment."))
        }

        if fm.fileExists(atPath: root.appendingPathComponent("pyproject.toml").path) ||
            fm.fileExists(atPath: root.appendingPathComponent("requirements.txt").path) {
            results.append(.init(id: "python", title: "Python project", command: "python3 -m ", explanation: "Complete the module name yourself; no entry point was inferred."))
        }
        return results
    }
}

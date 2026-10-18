import XCTest
@testable import TrisServerManager

final class HTTPReadinessConfigurationTests: XCTestCase {
    func testKnownServersResolveHealthPaths() {
        let auth = ServiceDefinition(name: "TrisAuthenticationServer", kind: .command, workingDirectory: "/tmp", command: "swift run Auth", port: 8080, group: "")
        let workout = ServiceDefinition(name: "WakTrainerServer", kind: .command, workingDirectory: "/tmp", command: "swift run Workout", port: 8081, group: "")
        XCTAssertEqual(auth.effectiveHealthCheckPath, "/hello")
        XCTAssertEqual(workout.effectiveHealthCheckPath, "/health")
    }

    func testLegacyJSONWithoutHealthPathStillDecodes() throws {
        let service = ServiceDefinition(name: "WakTrainerServer", kind: .command, workingDirectory: "/tmp", command: "swift run Workout", port: 8081, group: "")
        let encoded = try JSONEncoder().encode(service)
        let decoded = try JSONDecoder().decode(ServiceDefinition.self, from: encoded)
        XCTAssertEqual(decoded.effectiveHealthCheckPath, "/health")
    }

    func testCustomHealthPathAndValidation() {
        var service = ServiceDefinition(name: "Custom", kind: .command, workingDirectory: "/tmp", command: "npm run dev", port: 3001, group: "")
        service.healthCheckPath = "/api/health"
        XCTAssertEqual(service.effectiveHealthCheckPath, "/api/health")
        XCTAssertNil(service.validate())
        service.healthCheckPath = "//other-host"
        XCTAssertNotNil(service.validate())
    }
}

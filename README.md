# TrisServerManager

A native **macOS development server dashboard** built with SwiftUI. Register local commands and Docker Compose services, control them from a desktop window or menu bar, and inspect status and logs without keeping a row of Terminal windows open.

> **Status:** Developer preview. GitHub Actions validates the macOS build and unit tests, but real-machine smoke testing with your projects is still required. This is a local developer utility, not a production orchestrator.

## Requirements

- macOS 14+
- Xcode with macOS SDK, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Swift 5.9+
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) and Docker Compose for Docker services
- Locally installed Swift, Node.js, Python or other runtimes for the commands you register

The app has been designed as a non-sandboxed local developer tool. Run only commands and Docker projects you trust.

## Build and run

Clone the repository and generate the Xcode project:

```bash
git clone https://github.com/iosdevbyul/TrisServerManager.git
cd TrisServerManager
brew install xcodegen
xcodegen generate
open TrisServerManager.xcodeproj
```

Select the **TrisServerManager** scheme and **My Mac** destination, then Run in Xcode.

To run tests:

```bash
xcodebuild test \
  -project TrisServerManager.xcodeproj \
  -scheme TrisServerManager \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

To create a local unsigned build (not a notarized installer):

```bash
xcodebuild build \
  -project TrisServerManager.xcodeproj \
  -scheme TrisServerManager \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

The build can be found under `DerivedData/Build/Products/Release/`. Unsigned local builds may require macOS security approval on your own machine. No signed, notarized, downloadable release is currently published.

## Register services

### Local commands

1. Click **+** in the sidebar.
2. Optionally select a **Quick Setup** preset or use **Detect Project Commands** after selecting a folder.
3. Use **Browse** to choose the real local project directory.
4. Review and edit the start command and optional TCP port.
5. Save, then use **Start** or **Stop**.

Preset templates are editable and are **not** automatically executed. The DonghakStockVision API preset intentionally leaves its unknown launch command blank; the TrisMarketLens template leaves its port unset because 3000 may be taken by Grafana. Review environment activation, runtime arguments, working directory and secrets before starting.

### Docker Compose

1. Click the Docker import icon in the sidebar toolbar.
2. Browse to a directory containing your Compose configuration.
3. Click **Discover** to list services using `docker compose config --services`.
4. Select services and click **Import Selected**.
5. Start/stop an individual service as needed.

The import flow reads configuration; it does not start or remove containers. Docker control uses service-specific `docker compose up -d <service>` and `docker compose stop <service>`. It never invokes `docker compose down -v`, `docker volume rm` or Docker prune.

## Controls and monitoring

| Feature | Behavior |
| --- | --- |
| Start / Stop | Controls a registered local command or Compose service |
| Start All | Starts registered Docker Compose entries first, then local commands |
| Stop All | Requests local-command termination before stopping registered Docker entries |
| Menu bar | Offers per-service Start/Stop and bulk controls |
| Refresh All / Auto Refresh | Refreshes Docker status; automatic updates every 10 seconds while dashboard task is active |
| Logs | Local command stdout/stderr; for Docker a snapshot of the last 200 lines |
| Port checks | Best-effort TCP listener detection before starting a local command when a port is configured |
| Delete registration | Removes local metadata only, not processes, containers or volumes |

**Important:** Starting a Compose service with `up -d` does not guarantee its database or dependent API is ready. Docker entries start before local commands, but health/readiness checks and dependency-aware waits are **not yet implemented**. Use the individual controls if your stack requires a precise boot order.

**Process ownership:** The app can safely stop local commands it launched in its current session. It does not adopt or kill an unrelated Terminal process. On normal app termination, the app requests termination of the local processes it owns. Docker containers are left running when the app quits. A force quit/crash can leave launched child processes running, and reopening the app does not reattach to them; their status can be **Unknown**. Check the port and external processes before starting again.

**Log caveats:** Docker logs are periodic, bounded snapshots rather than a persistent streaming session. The dashboard's auto-refresh is tied to the view lifecycle, not a guaranteed background daemon. No CPU/memory telemetry or HTTP health probe is available yet.

## Service data

Registrations are saved as JSON under:

```text
~/Library/Application Support/TrisServerManager/services.json
```

A registration contains a UUID, name, kind, working directory, command/Compose service, optional port and group. Never add API keys or passwords to commands or a public repository. Back up the JSON file before manual edits.

## Suggested local setup

| Service | Kind | Known port / notes |
| --- | --- | --- |
| DonghakStockVision API | Local command | Verify command and port yourself |
| TrisMarketLens | Local command | `npm run dev`; verify port before use |
| WakTrainerServer | Local command | `swift run WakTrainerServer serve --hostname 127.0.0.1 --port 8081` |
| TrisAuthenticationServer | Local command | `swift run TrisAuthenticationServer serve --hostname 127.0.0.1 --port 8080` |
| WakTrainer PostgreSQL | Docker Compose | Previously observed host port 5433 |
| WakTrainer auth PostgreSQL | Docker Compose | Previously observed host port 5434 |
| Donghak Grafana | Docker Compose | Previously observed host port 3000 |
| Donghak Prometheus | Docker Compose | Previously observed host port 9090 |

Do not register a container as a local command merely because Docker Desktop lists it. Import the correct Compose service from its configuration directory. **TrisMarketLens and Grafana may compete for host port 3000**; confirm which port each actually binds before starting both.

## Manual smoke-test checklist

- [ ] Generate the project, build and launch the app on the target Mac.
- [ ] Register, edit, delete and re-register a harmless test command; restart the app and confirm persistence.
- [ ] Start a harmless local HTTP server; confirm Running, logs, and Stop behavior.
- [ ] Confirm a deliberately occupied port is rejected rather than silently reused.
- [ ] Import an existing Compose project; check that already running services are recognized.
- [ ] Start/stop a disposable Compose service; verify that Docker volumes and other services remain untouched.
- [ ] Confirm Start All and Stop All order with a disposable mixed stack.
- [ ] Quit and reopen the app; verify Docker state and understand Unknown status for unowned local processes.
- [ ] Check menu-bar commands and auto-refresh.
- [ ] Validate the actual Python virtualenv, Swift targets, Node dependencies, and database readiness for your four applications.

## Architecture

- `ServiceDefinition`: persisted service settings
- `ServiceStore`: JSON registry
- `ServiceRuntime`: execution, status, and log coordination
- `RuntimeDiagnostics`: TCP listening-port check
- `ComposeServiceDiscovery`: Compose service discovery
- `LocalProjectDetector` / `DevelopmentServicePreset`: optional command suggestions and known templates
- `DashboardView`, `ServiceEditorView`, `ComposeImportView`: native macOS UI

The UI reuses [WakTrainerDesignSystem](https://github.com/iosdevbyul/WakTrainerDesignSystem), pinned to a specific compatible commit in `project.yml`.

## Known limitations

- No reconnect-to-PID mechanism for local services after an app restart.
- No HTTP readiness probing or guaranteed dependent-service startup ordering.
- No guaranteed cleanup after a crash, force quit or power failure.
- No automatic discovery of arbitrary local server entry points.
- No production daemon, installer, signed/notarized release, or remote server management.

## Development

Changes should use a feature branch, tests, a pull request and macOS CI before merging into `main`. CI is useful but does not replace testing with Docker Desktop and the actual server repositories on a Mac.

## License

No license is declared in this repository. All rights are reserved unless a license is added.

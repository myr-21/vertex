# Vertex

**Vertex** — *A Lightweight Local Container Orchestration & Platform Engineering Toolkit*

Vertex is a production-quality, open-source platform engineering toolkit that provides a lightweight local container orchestration environment inspired by Heroku, Render, Docker Swarm, and Kubernetes. It enables developers to deploy, manage, monitor, and automate containerized applications locally while demonstrating clean software architecture, state management, transactions, and DevOps concepts.

---

## Phase 3 Architecture: Docker Integration

Vertex integrates the native `docker` CLI tool inside the unified **Resource Manager** abstraction:

```
CLI ──> Command Module ──> Orchestrator ──> Planner ──> Execution Plan (JSON)
                                                           │
                                                           ▼
SUCCESS <── State Engine <── Resource Manager <── Executor <── Transaction Manager (LIFO Rollback)
                                   │
                                   ▼
                              Docker CLI
```

### Components
1. **Resource Manager (`lib/resource.sh`)**: Exposes container, network, and volume actions (`resource_action`). It verifies image presence (pulls if missing), checks port bindings on the host, and inspects container metadata.
2. **State Engine (`lib/state.sh`)**: Serializes verified docker parameters directly from inspect output into `state/current/` config JSONs.
3. **Transaction Manager (`lib/transaction.sh`)**: Intercepts step failures to invoke LIFO rollback steps, cleanly deleting spawned containers, networks, and volumes.

---

## Prerequisites

Before running Vertex, ensure you have the following installed on your machine:
- **Bash** shell (WSL 2 on Windows, macOS Terminal, or Linux).
- **Docker Engine** (running daemon). On Windows, make sure **Docker Desktop** is running and WSL integration is active.
- **jq** command-line JSON processor.

---

## Installation

To install Vertex:

```bash
git clone https://github.com/myr-21/vertex.git
cd vertex
./install.sh
```

Ensure `~/.local/bin` is added to your environment `PATH` to run `vrtx` globally.

---

## CLI Examples

### Print Version Check
```bash
vrtx version
```

### Show Application Dashboard
```bash
vrtx status
```

### Deploy Template
```bash
vrtx deploy nginx-test nginx:alpine 8080
```

### Destroy Template
```bash
vrtx destroy nginx-test
```

---

## Troubleshooting

### Docker Daemon Not Running
If you receive the error:
`Error (Resource): Docker daemon is not running or unreachable`
- On Windows: Open Docker Desktop and wait for the status indicator to turn green.
- On Linux/macOS: Run `sudo systemctl start docker` or verify your current user permissions inside the `docker` group.

---

## Contributing

We welcome contributions! Please review our specifications before opening pull requests.

## License

This project is licensed under the MIT License.

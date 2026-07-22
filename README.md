# Vertex

**Vertex** — *A Lightweight Local Platform-as-a-Service (PaaS)*

Vertex is a lightweight local Platform-as-a-Service (PaaS) that provisions and manages containerized applications using a transactional control plane built in Bash. It enables developers to deploy, manage, monitor, and automate containerized applications locally while demonstrating clean software architecture, state management, transactions, and DevOps concepts.

---

## Prerequisites

Before running Vertex, ensure you have the following installed on your machine:
- **Bash** shell (WSL 2 on Windows, macOS Terminal, or Linux).
- **Docker Engine** (running daemon). On Windows, make sure **Docker Desktop** is running and WSL integration is active.
- **jq** command-line JSON processor:
  - **Windows (Winget)**: `winget install jqlang.jq`
  - **macOS (Homebrew)**: `brew install jq`
  - **Ubuntu/Debian**: `sudo apt-get install -y jq`
  - **CentOS/RHEL**: `sudo dnf install -y jq`

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

### Example Session

```bash
$ ./vrtx deploy webserver nginx:alpine 8080

ℹ Deploying application: webserver (Tx: tx-20260722-135647-adzCxu)
✔ Deployment of webserver completed successfully!

$ ./vrtx status

APP          STATUS    IMAGE          PORT   
---------------------------------------------
webserver    running   nginx:alpine   8080   

$ curl -I http://localhost:8080

HTTP/1.1 200 OK
Server: nginx/1.27.4

$ ./vrtx destroy webserver

ℹ Destroying application: webserver (Tx: tx-20260722-135704-5q8M3g)
✔ Application webserver destroyed successfully.
```

### Command Reference

#### Print Version Check
```bash
./vrtx version
```

#### Show Application Dashboard
```bash
./vrtx status
```

#### Deploy Template
```bash
./vrtx deploy nginx-test nginx:alpine 8080
```

#### Destroy Template
```bash
./vrtx destroy nginx-test
```

---

## Troubleshooting

### Docker Daemon Not Running
If you receive the error:
`Error (Resource): Docker daemon is not running or unreachable`
- On Windows: Open Docker Desktop and wait for the status indicator to turn green.
- On Linux/macOS: Run `sudo systemctl start docker` or verify your current user permissions inside the `docker` group.

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
1. **Resource Manager (`lib/resource.sh`)**: Exposes container run, network creation, volume allocation, and status checks.
2. **State Engine (`lib/state.sh`)**: Serializes verified docker parameters directly from inspect output into `state/current/` config JSONs.
3. **Transaction Manager (`lib/transaction.sh`)**: Intercepts step failures to invoke LIFO rollback steps, cleanly deleting spawned containers, networks, and volumes.

# Vertex

**Vertex** — *A Lightweight Local Container Orchestration & Platform Engineering Toolkit*

Vertex is a production-quality, open-source platform engineering toolkit that provides a lightweight local container orchestration environment inspired by Heroku, Render, Docker Swarm, and Kubernetes. It enables developers to deploy, manage, monitor, and automate containerized applications locally while demonstrating clean software architecture, state management, transactions, and DevOps concepts.

---

## Architecture Overview

Vertex decouples operations using a **Control Plane** and a **Resource Manager** to avoid raw/direct container engine mutations:

```
                       User
                         │
                    vrtx CLI (vrtx)
                         │
                 Argument Parser
                         │
               Command Dispatcher (commands/*)
                         │
            Validation / Permission Layer
                         │
               Control Plane (engine/*)
                         │
               Planner (planner.sh)
                         │
               Execution Plan
                         │
               Executor (executor.sh)
                         │
               Resource Manager (lib/resource.sh)
                         │
       ┌─────────────────┼─────────────────┐
       ▼                                   ▼
  State Engine                        Docker Engine
(state/registry.json)              (lib/docker.sh)
```

---

## Folder Structure

```
vertex/
├── bin/            # CLI binary entry point (symlink to vrtx)
├── commands/       # Subcommand modules (deploy.sh, destroy.sh, doctor.sh, etc.)
├── engine/         # Decoupled control plane modules
├── lib/            # Shared libraries (logger.sh, validation.sh, table.sh, etc.)
├── state/          # Partitioned state directories (desired/, current/, history/)
├── runtime/        # Generated runtime configs and lock files
├── templates/      # Base templates with lifecycle hooks
├── compose/        # Core platform service definitions
├── backups/        # Compressed archive files for backups
├── logs/           # Organized log files (platform/, applications/, transactions/)
├── tests/          # Bats test suites
└── docs/           # System design & architecture guides
```

---

## Project Status (Release Candidate v0.1.0)

- **Completed Phase 1 (Foundation)**:
  - Command parsing, dispatcher routing, and concurrency locking checks.
  - Multi-level logging library (`logger.sh`), strict validations (`validation.sh`), and tabular printer (`table.sh`).
  - Automated installers (`install.sh`, `uninstall.sh`) and architecture records (ADRs).
  - Validation test suites utilizing the Bats testing framework.
- **Planned Phases (2 to 6)**:
  - Docker Resource Manager and deployment transitions with automated transaction rollback.
  - Custom manifest engine reconciler (`vrtx apply app.yaml`) and dynamic Nginx proxy.
  - Prometheus/Grafana operations stack, logging, diagnostic reports (`vrtx doctor`), backups.
  - Interactive Terminal TUI dashboard, Kubernetes manifest export.

---

## Installation

To install Vertex locally:

```bash
git clone https://github.com/your-username/vertex.git
cd vertex
./install.sh
```

Ensure `~/.local/bin` is added to your environment `PATH` to execute `vrtx` globally.

---

## Quick Start & CLI Examples

### Print Version Check
```bash
vrtx version
```

### Show Application Dashboard (Planned)
```bash
vrtx status
```

### Deploy Template (Planned)
```bash
vrtx deploy nginx
```

---

## Contributing

We welcome contributions! Please review our development specifications before opening pull requests.

## License

This project is licensed under the MIT License.

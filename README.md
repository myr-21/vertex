# Vertex

**Vertex** — *A Lightweight Local Container Orchestration & Platform Engineering Toolkit*

Vertex is a production-quality, open-source platform engineering toolkit that provides a lightweight local container orchestration environment inspired by Heroku, Render, Docker Swarm, and Kubernetes. It enables developers to deploy, manage, monitor, and automate containerized applications locally while demonstrating clean software architecture, state management, transactions, and DevOps concepts.

---

## Phase 2 Core Runtime Architecture

Vertex implements a strict Planner-Executor transaction loop to coordinate resources safely:

```
CLI ──> Command Module ──> Orchestrator ──> Planner ──> Execution Plan (JSON)
                                                           │
                                                           ▼
SUCCESS <── State Engine <── Resource Manager <── Executor <── Transaction Manager (LIFO Rollback)
```

### Components
1. **JSON Library (`lib/json.sh`)**: Interacts with JSON schemas using standard `jq` path expressions.
2. **State Engine (`lib/state.sh`)**: The only module allowed to read or write state data inside `state/`.
3. **Resource Manager (`lib/resource.sh`)**: Single adapter layer abstracting infrastructure commands.
4. **Transaction Manager (`lib/transaction.sh`)**: Coordinates steps execution and pushes rollback actions onto a LIFO stack.
5. **Planner (`engine/planner.sh`)**: Computes required forward steps and outputs plans inside `runtime/plans/<tx-id>.json`.
6. **Executor (`engine/executor.sh`)**: Executes plan JSON arrays sequentially and triggers LIFO rollback on failures.
7. **Orchestrator (`engine/orchestrator.sh`)**: Coordinates workflow steps from thin command modules.

---

## Folder Structure

```
vertex/
├── bin/            # CLI binary entry point (symlink to vrtx)
├── commands/       # Subcommand modules (deploy.sh, destroy.sh, status.sh)
├── engine/         # Control plane modules (planner.sh, executor.sh, orchestrator.sh)
├── lib/            # Shared libraries (json.sh, state.sh, transaction.sh, error.sh, constants.sh)
├── state/          # Partitioned state directories (desired/, current/, history/)
├── runtime/        # Generated runtime configs, locks, and plans/
├── templates/      # Base templates with lifecycle hooks
├── compose/        # Core platform service definitions
├── backups/        # Compressed archive files for backups
├── logs/           # Organized log files (platform/, applications/, transactions/)
├── tests/          # Bats test suites (unit/ and integration/)
└── docs/           # System design & architecture guides
```

---

## Installation

To install Vertex locally:

```bash
git clone https://github.com/myr-21/vertex.git
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

### Show Application Dashboard
```bash
vrtx status
```

### Deploy Application
```bash
vrtx deploy nginx-test
```

### Destroy Application
```bash
vrtx destroy nginx-test
```

---

## Contributing

We welcome contributions! Please review our development specifications before opening pull requests.

## License

This project is licensed under the MIT License.

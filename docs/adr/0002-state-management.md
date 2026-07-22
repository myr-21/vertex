# ADR 0002: State Management Partitioning

## Context
Vertex needs a reliable state store that mirrors running container configuration without relying solely on slow Docker CLI inspections.

## Decision
We store configuration in partitioned folders under `state/`:
- `state/desired/` containing desired target states.
- `state/current/` containing current actual states.
- `state/history/` storing timestamped versions.
- `state/registry.json` acting as the master lookup index.

## Consequences
- **Pros**: Independent of Docker daemon speeds, atomic rollbacks.
- **Cons**: Requires keeping filesystem state synchronous with Docker daemon.

# ADR 0003: Runtime Locking

## Context
Concurrent deployments or state updates can lead to corrupted registry indexes or double allocations of Docker resources.

## Decision
We enforce a file-lock pattern using `flock` on `runtime/locks/global.lock` for all state-mutating operations. Read-only commands bypass locking.

## Consequences
- **Pros**: Thread-safe operations, prevents race conditions.
- **Cons**: Commands block or fail fast when another is active.

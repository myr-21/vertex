# ADR 0001: Planner-Executor Architecture

## Context
Standard bash CLIs often run commands directly. This leads to configuration drift, poor rollback mechanisms, and difficult state debugging.

## Decision
We decouple configuration generation, operation planning, and operation execution.
- **Planner** generates execution plans but modifies nothing.
- **Executor** executes plans and coordinates transaction rollbacks.

## Consequences
- **Pros**: Easy validation, testability, predictable execution, and safety.
- **Cons**: Slightly higher code structure overhead.

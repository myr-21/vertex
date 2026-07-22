# Vertex Overview

Vertex is a lightweight container orchestration platform designed to run locally, providing a Heroku-like PaaS developer experience directly on top of Docker and Nginx.

## Architecture Pipeline

Operations triggered via `vrtx` follow a structured control loop:

1. **vrtx CLI**: Direct user interaction interface.
2. **Argument Parser / Dispatcher**: Routes CLI arguments to commands.
3. **Control Plane (Planner & Executor)**: Generates deterministic execution plans and reconciles states without direct resource calls.
4. **Resource Manager**: Decouples executor from raw Docker APIs, managing networks, containers, and proxy configurations.
5. **State Engine**: Writes state declarations and auditing data to file systems.

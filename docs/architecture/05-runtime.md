# Runtime Environment

Vertex isolation is managed by storing transient components separate from source files:

- **locks/**: Operational flock descriptors preventing concurrent mutations.
- **pid/**: Running background processes.
- **cache/**: Internal metadata indices.
- **generated/**: Templates parsed dynamically during deploy.
- **compose/**: Docker Compose blueprints.
- **proxy/**: Nginx proxy profiles and route mappings.

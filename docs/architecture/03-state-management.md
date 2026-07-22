# State Management

Vertex uses local JSON registries to track desired, current, and historical states.

- **desired/**: Target config specifications (manifests, input args).
- **current/**: Verified configurations matching running infrastructure.
- **history/**: Timestamped state revisions for rollback.
- **registry.json**: Main registry indexing active applications.

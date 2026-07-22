# Deployment Flow

Vertex deploys applications transactionally. The orchestrator routes the request:

```
[CLI] -> [Planner] -> [Plan Output] -> [Executor] -> [Resource Manager] -> [State Update]
```

## Step-by-Step Sequence:

1. **Validation**: Check for configuration schemas and conflict issues (ports, networks).
2. **Plan Generation**: Generate a list of operations needed.
3. **Execution**:
   - Create Docker Network
   - Create Docker Volume
   - Pull & Run Docker Container
   - Dynamically Update Nginx Reverse Proxy
   - Perform Health Check
4. **Finalize State**: Persist details to current state registry.

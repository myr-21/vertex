# Vertex Architecture Overview

Vertex is a lightweight local container orchestration platform. This document outlines the standard conventions, schemas, and library contracts.

## 1. Unified Library Contract (`lib/*`)
Every helper module under `lib/` adheres to these rules:
1. **Stdout Communication**: Data is returned exclusively via `stdout`.
2. **Exit Codes**: Functions signal success/failure status using standard numeric exit codes.
3. **No Process Termination**: Libraries must **never** call `exit`. They return status codes so callers can handle exceptions.
4. **Console Output**: Logging/terminal outputs are restricted to `logger.sh` functions.

## 2. Standardized Exit Codes
- `0`: Success
- `1`: General failure
- `2`: Invalid arguments
- `3`: Validation failed
- `4`: Resource failure
- `5`: Transaction rollback
- `6`: Unsupported plan version

## 3. Log Format
Internal platform logs in `logs/platform/system.log` are formatted as follows:
`[TIMESTAMP] [TRANSACTION_ID] [LEVEL] [MODULE] message`
- Example: `[2026-07-22T16:00:00Z] [tx-20260722-160000-a1b2c3] [INFO] [EXECUTOR] Starting deploy for nginx`

## 4. Transaction ID Format
Every transaction generates an identifier formatted as:
`tx-YYYYMMDD-HHMMSS-XXXXXX`
- Example: `tx-20260722-143015-a1b2c3`

## 5. Execution Plan Schema
Plan files are stored in `runtime/plans/<transaction-id>.json`:
```json
{
  "version": 1,
  "transaction_id": "tx-20260722-143015-a1b2c3",
  "action": "deploy",
  "application": "nginx",
  "generated_at": "2026-07-22T16:00:00Z",
  "status": "planned",
  "steps": [
    {
      "id": 1,
      "action": "create_network",
      "rollback": "delete_network",
      "status": "pending"
    }
  ]
}
```

## 6. Application State Schema
Individual app records are kept in `state/current/<app-name>.json`:
```json
{
  "schema_version": 1,
  "id": "...",
  "name": "nginx",
  "template": "...",
  "image": "nginx:latest",
  "version": "latest",
  "status": "planned",
  "health": "unknown",
  "ports": [80],
  "volumes": [],
  "networks": [],
  "dependencies": [],
  "created_at": "...",
  "updated_at": "...",
  "last_deployment": "...",
  "last_backup": "..."
}
```

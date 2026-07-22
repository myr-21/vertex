# Transactions & Rollbacks

All state-modifying operations (deployments, updates, and destructions) execute inside a transaction wrapper:

1. Operations are recorded to an execution plan.
2. If any step fails (e.g. database connection times out or container health check fails), the Executor catches the error.
3. The Executor steps backward through the execution history, reversing all completed steps (deleting container, pruning networks, reverting Nginx configurations).

# ADR 0004: Reverse Proxy Routing

## Context
Applications deployed on Vertex should be instantly accessible via path-based routing or subdomains on localhost without requiring port exposing manually.

## Decision
We utilize a dynamic Nginx reverse proxy service. Nginx reads generated site mapping files inside `runtime/proxy/` which are reloaded automatically on deployment success.

## Consequences
- **Pros**: Dynamic routing, port virtualization, neat local URLs.
- **Cons**: Requires Nginx configuration updates and docker bridge networking setup.

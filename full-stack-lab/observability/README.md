# Observability (Prometheus + Grafana)

Status: artifacts built, NOT live-verified in the build sandbox (relative bind mounts fail
under Git Bash here, run from PowerShell or WSL). The stack itself is standard.

## Bring up

```
docker compose -p zo -f compose/controllers.yml -f compose/observability.yml up -d prometheus grafana
```

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin / admin; anonymous viewing enabled)

## Enable Ziti controller metrics (required for non-empty graphs)

Ziti only serves `/metrics` when the controller config declares a Prometheus metrics handler on
a web listener API binding. Add this to each controller's `config.yml` under the existing web
listener `apis:` list, then restart the controller:

```yaml
      - binding: metrics
        options:
          includeTimestamps: true
```

and a metrics section:

```yaml
metrics:
  handler:
    type: prometheus
```

Exact keys vary by version, confirm against the controller reference for 2.0.0. Routers can also
emit metrics via their own config. Once enabled, the `ziti-controllers` job in
`observability/prometheus/prometheus.yml` will go UP and you can build dashboards on circuit
counts, link latency, API session counts, and terminator health.

## Dashboards

`observability/grafana/datasource.yml` provisions the Prometheus datasource. Import or build a
dashboard in Grafana once metrics flow. A good starter set of panels: active circuits, links by
state, link source/dest latency, edge sessions, controller raft leader.

# Controller internals (v2.0.0 image), as observed

Facts pulled from a running `openziti/ziti-controller:2.0.0` bootstrap. Source of truth for later wiring.

## PKI layout (inside the controller volume, paths relative to `/ziti-controller`)

- Root CA cert: `pki/root/certs/root.cert`
- Intermediate cert: `pki/intermediate/certs/intermediate.cert`
- Intermediate key: `pki/intermediate/keys/intermediate.key` (also the edge enrollment signing cert/key)
- Server chain: `pki/intermediate/certs/server.chain.pem`
- Client chain: `pki/intermediate/certs/client.chain.pem`
- Server key: `pki/intermediate/keys/server.key`

Nodes 2 and 3 were bootstrapped with `ZITI_CLUSTER_NODE_PKI=/ctrl1-state/pki`, so their intermediates chain to node
1's root. The **root CA is common across all three nodes**.

## Server cert SANs

The bootstrap (`bootstrap.bash` `issueLeafCerts()`) sets server SANs to exactly `localhost` + `127.0.0.1,::1` +
`ZITI_CTRL_ADVERTISED_ADDRESS`. There is **no env var for extra SANs**, and the cert-renewal timer recomputes SANs
the same way, so any hand-edited SAN on the primary cert is wiped on renewal.

## Front-door name (`learning.openziti.local`) plan

The web listener identity supports `alt_server_certs` (commented stub in generated `config.yml`, lines ~180-182):

```yaml
identity:
  ca:          "pki/root/certs/root.cert"
  server_cert: "pki/intermediate/certs/server.chain.pem"
  alt_server_certs:
  - server_cert: "pki/intermediate/certs/frontdoor.server.chain.pem"
    server_key:  "pki/intermediate/keys/frontdoor.server.key"
```

Plan: issue a `learning.openziti.local` server cert from the shared CA, set it as `alt_server_certs` on every node's
web listener. Clients trust the common root, so they validate it no matter which node HAProxy routes them to. This is
additive and survives renewal (renewal only touches the primary leaf). Implemented when the HAProxy front door is
built.

Caveat to handle then: `config.yml` is generated once by `ZITI_BOOTSTRAP_CONFIG`. To keep the `alt_server_certs`
edit, either set `ZITI_BOOTSTRAP_CONFIG=false` after first boot or re-apply the edit idempotently in a script.

## ZAC (admin console)

Served by every controller already, no extra container: web listener `client-management`, `spa` binding,
`location: /ziti-console`, path `zac`. Reachable at `https://<controller>:<port>/zac` (node 1: `:1280`, node 2:
`:1282`, node 3: `:1283`).

## Edge / API endpoints

- Client + management + fabric + OIDC APIs all on the one web listener (`0.0.0.0:1280` on node 1).
- Edge enrollment signing cert: `pki/intermediate/certs/intermediate.cert`.

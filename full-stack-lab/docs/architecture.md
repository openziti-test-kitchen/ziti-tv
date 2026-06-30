# Architecture (as built)

Live topology of the `ziti-overkill` lab. This reflects what is actually running, not the aspirational plan.

## Control plane

```mermaid
flowchart TB
  subgraph cluster["HA controller cluster (raft)"]
    C1[("ziti-controller1\nLEADER :1280")]
    C2[("ziti-controller2\nvoter :1282")]
    C3[("ziti-controller3\nvoter :1283")]
    C1 <-->|raft| C2
    C2 <-->|raft| C3
    C1 <-->|raft| C3
  end
  note["ZAC console on every node at /zac"]
  cluster --- note
```

- 3-node raft cluster. One leader, two voters. Each node also serves the edge/management/fabric APIs and ZAC.
- PKI bootstrapped by node 1; nodes 2/3 chain to node 1's root, so the root CA is common.

## Data plane (routers + emulated sites)

Every router attaches to the `ziti` control network (to reach the controllers) plus the site network(s) it
represents. The fabric currently forms a FULL MESH (15 links) because routers can all reach each other over `ziti`.

```mermaid
flowchart LR
  subgraph internet
    PUB[public-er-1\nedge, tun host]
    TR[transit-router\ntransit-only]
  end
  subgraph vpc1
    V1[vpc1-er\nedge, tun host]
  end
  subgraph vpc2
    V2[vpc2-er\nedge, tun host]
    BE[echo-backend\nwhoami :80 dark]
  end
  subgraph home
    HE[home-er\nedge]
    CL[echo-client\nproxy :8080]
  end
  subgraph corp
    CE[corp-er\nedge, tun host]
  end
  HOST[echo-host\nbinds echo]

  CL -.dial.-> HE
  HOST -.bind.-> V2
  HOST --> BE
  PUB --- TR --- V1 --- V2 --- CE --- HE
  classDef dark fill:#222,color:#eee;
  class BE dark;
```

## Echo service path (first dial)

```mermaid
sequenceDiagram
  participant CL as echo-client (proxy :8080)
  participant ER as edge router
  participant FB as fabric
  participant HO as echo-host
  participant BE as echo-backend (whoami)
  CL->>ER: dial service "echo"
  ER->>FB: circuit
  FB->>HO: terminator
  HO->>BE: tcp 80
  BE-->>CL: HTTP response (whoami)
```

## Identities and policies (echo)

```mermaid
flowchart LR
  EC[echo-client\n#echo.clients] -->|Dial: echo-dial| SVC[(service echo)]
  EH[echo-host\n#echo.servers] -->|Bind: echo-bind| SVC
  SVC --> HCFG[host.v1 -> echo-backend:80]
  SVC --> ICFG[intercept.v1 -> echo.ziti:80]
  EC --> ERP[edge-router-policy erp-all #all->#all]
  SVC --> SERP[service-edge-router-policy serp-all #all->#all]
```

## Ports (host-published)

| Service | Host port |
|---|---|
| ziti-controller1 (API + ZAC) | 1280 |
| ziti-controller2 | 1282 |
| ziti-controller3 | 1283 |
| public-er-1 | 3022 |
| transit-router | 3023 |
| vpc1-er | 3024 |
| vpc2-er | 3025 |
| corp-er | 3026 |
| home-er | 3027 |
| echo-client proxy | (internal :8080) |

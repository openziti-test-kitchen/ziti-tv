# Module 6 - "Production concerns"

**Stage setup:** `bash scripts/stage.sh module-6` (full lab).

---

## module-6.a - Seeing the network: observability (8 min)

**GOAL:** Metrics + dashboards for the overlay.

**COLD OPEN:**
> "You can't run what you can't see. Let's wire up Prometheus and Grafana."

**SAY / DO:**
- SAY: "Enable Prometheus metrics on the controller (one config block), then bring up the stack." DO:
  ```
  docker compose -p zo -f compose/controllers.yml -f compose/observability.yml up -d prometheus grafana
  ```
  (see `observability/README.md` for the controller metrics config snippet)
- SAY: "Prometheus is scraping the controllers." DO: open http://localhost:9090, show targets UP.
- SAY: "Grafana graphs it." DO: open http://localhost:3000, show the Prometheus datasource and a circuit/link
  dashboard.

**TAKEAWAY:** "Ziti exposes Prometheus metrics, circuits, links, latency, sessions, so you monitor the overlay
like any other production system."

**DON'T SHOW:** building every panel; show a couple that matter (active circuits, link latency).

---

## module-6.b - It keeps working when things die (8 min)

**GOAL:** The overlay survives host and controller failures.

**COLD OPEN:**
> "Let's break things on purpose and watch traffic shrug it off."

**SAY / DO:**
- SAY: "Two hosts back the echo service. Kill one." DO:
  ```
  bash scripts/demo-chaos.sh kill-host       # echo still returns 200 via the other host
  bash scripts/demo-chaos.sh restore-host
  ```
- SAY: "Now kill the raft LEADER. The cluster re-elects and the data plane never blinks." DO:
  ```
  bash scripts/demo-chaos.sh kill-leader
  bash scripts/demo-chaos.sh restore-leader
  ```

**TAKEAWAY:** "Multiple terminators give service-level HA, the raft cluster gives control-plane HA, and existing
data flows are independent of the controller entirely."

**DON'T SHOW:** killing a router a proxy client uses as its only edge entry (that drops the client) - use host and
leader failures, which are the clean stories.

---

## module-6.c - Steering traffic: path shaping (7 min)

**GOAL:** Smart routing picks lowest cost, and you can bias it.

**COLD OPEN:**
> "Traffic takes the cheapest path. Change the cost and it takes a different one."

**SAY / DO:**
- DO: hold a connection open, then:
  ```
  bash scripts/demo-path.sh circuits          # note the PATH (which routers/links)
  bash scripts/demo-path.sh links             # copy a link ID on that path
  bash scripts/demo-path.sh cost <linkId> 1000
  bash scripts/demo-path.sh circuits          # new connections route around it
  bash scripts/demo-path.sh reset <linkId>
  ```

**TAKEAWAY:** "Link cost is a knob: raise it to drain a link, lower it to prefer a route, smart routing does the
rest and reroutes live."

**DON'T SHOW:** terminator strategy math; keep it to link cost.

---

## module-6.d - Backups (5 min)

**GOAL:** Snapshot the controller database.

**COLD OPEN:**
> "Your whole network config lives in one database. Back it up."

**SAY / DO:**
- DO:
  ```
  bash scripts/backup-restore.sh snapshot       # writes a timestamped snapshot to backups/
  ```
- SAY: "Restore is: stop the controller, drop the snapshot in place of the bolt DB, start it. In HA, restore on
  a fresh single node and re-add peers."

**TAKEAWAY:** "One command snapshots the entire overlay definition, identities, services, policies, PKI metadata."

**DON'T SHOW:** a full restore (describe it); the snapshot is the demo.

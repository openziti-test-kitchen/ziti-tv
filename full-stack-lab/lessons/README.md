# Lessons: "What the fuck even is OpenZiti" video scripts

Shooting scripts for the series outlined in `docs/curriculum.md`. 13 episodes, 3 modules, 4-10 min each.

Format of each episode:
- **GOAL** - the one sentence a viewer should be able to say after watching.
- **COLD OPEN** - the hook, read aloud.
- **SAY / DO** beats - narration paired with the exact on-screen command and expected result.
- **TAKEAWAY** - the closing line.
- **DON'T SHOW** - what to keep off screen so the episode stays small.

## Pick up from any episode (one command per stage)

You do not have to run the series in order. `scripts/stage.sh` brings the lab to exactly the
state a given Module needs and prints that module's first command:

```
bash scripts/stage.sh module-1     # Module 1: minimal stack (1 controller + 1 router + echo)
bash scripts/stage.sh module-2     # Modules 2-6: the full cumulative lab (all services/identities)
bash scripts/stage.sh module-3     # ...same lab; just jump into the Module 3 commands
bash scripts/stage.sh module-7     # Kubernetes (k8s/)
bash scripts/stage.sh down   # tear down both stacks (down -v for a clean slate)
bash scripts/stage.sh list   # show the map
```

Why this works: Modules 2-6 all run on ONE lab (`zo`) that is built cumulatively and
idempotently, every service, identity, and policy is present once it is up, so any episode's
commands work regardless of where you start. Module 1 uses the separate minimal stack (`zomin`)
so beginners see only two moving parts. The two stacks share host ports, so `stage.sh` stops
the other one for you.

Resume vs rebuild: `stage.sh` resumes a stopped lab fast (`scripts/start.sh`) or builds it from
scratch if it does not exist (`scripts/demo-up.sh`). For a guaranteed-clean recording, do
`bash scripts/down.sh -v` first, then `bash scripts/stage.sh module-N`.

## Two stacks

- **Minimal stack** (`scripts/lesson-up.sh`) - 1 controller + 1 router, project `zomin`. Used for the "look how
  few pieces" episodes (module-1.c). Tear down: `docker compose -p zomin -f compose/lesson-min.yml down -v`.
- **Full lab** (`scripts/demo-up.sh`) - the overkill stack, project `zo`. Used for the service, fabric, posture,
  HA, and multi-site episodes. The two share host ports 1280/3022, so run only ONE at a time.

Module 1 runs entirely on the minimal stack: `bash scripts/lesson-up.sh` then `bash scripts/lesson-echo.sh` give
you 1 controller + 1 router + the echo service. Module 2 needs the full `zo` lab (fabric needs multiple routers;
ssh is router-hosted on corp-er; the posture demo lives there). Module 3 is all `zo`.

## Recording prerequisites

- A real terminal (not the build sandbox). `docker exec -it ...` shows clean output there.
- Pre-pull images and pre-bring-up the relevant stack before rolling; enrollment + pulls are dead air.
- Log in once at the start: `docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`.
- ZAC (the web console) is at `https://localhost:1280/zac` (accept the self-signed cert).

## Episode index

Module 1 - what even is it: module-1.a the problem, module-1.b the five words, module-1.c hello overlay, module-1.d first dark service,
module-1.e identities & enrollment, module-1.f services/configs/policies.
Module 2 - how it works: module-2.a fabric/links/circuits, module-2.b two hosting patterns, module-2.c posture deny, module-2.d enrollment menu.
Module 3 - scaling up: module-3.a HA, module-3.b many sites, module-3.c the full monster.
Module 4 - real edges (`module4.md`): module-4.a dial by name, module-4.b your actual laptop (Desktop Edge), module-4.c SDK no tunneler.
Module 5 - advanced auth (`module5.md`): module-5.a UPDB + MFA, module-5.b bring your own CA, module-5.c revocation.
Module 6 - production (`module6.md`): module-6.a observability, module-6.b failure/resilience, module-6.c path shaping, module-6.d backups.
Module 7 - Kubernetes (`../k8s/LESSON.md`): a dark k8s service with no ingress.
Concepts module - why OpenZiti is different (`concepts.md`): concept.a five zero-trust principles, concept.b
end-to-end encryption, concept.c three planes, concept.d sessions & posture, concept.e the attachment spectrum,
concept.f SPIFFE/PKI, concept.g terminators & strategies, concept.h typed configs, concept.i adaptive routing.
Mostly explainer + read-only `ziti edge`/`fabric list` on the running lab. Stage: `bash scripts/stage.sh module-3`.
Pathing module - custom router paths & link groups (`pathing.md`): pathing.a circuits, pathing.b link-cost steer,
pathing.c force the home->internet->vpc1->vpc2 route, pathing.d reroute on failure, pathing.e link groups,
pathing.f recap. Stage: `bash scripts/stage.sh pathing`. Scripts: `scripts/provision-pathing.sh`,
`scripts/demo-longpath.sh`, `scripts/provision-linkgroups.sh`.
Interop module - polyglot SDK matrix (`interop.md`): interop.a echo across languages, interop.b the full green
grid, interop.c posture flips cells, interop.d auth policies vs posture, interop.e health-check failover,
interop.f link-group pathing. Built from `sdk/<lang>/`, `compose/interop.yml`, `scripts/provision-interop.sh`,
`scripts/interop-matrix.sh`, and the `scripts/provision-interop-*` layer scripts. Stage: `bash scripts/stage.sh
module-2` (full lab), then provision + bring up servers + run the matrix.

Verification status: live-verified here = module-1.c, module-1.d, module-4.a (dial-by-name), module-2.c/module-5.a (posture+MFA deny), module-6.b (host
failover), module-6.d (snapshot). Scripted/CLI = module-1.e-module-2.b, module-2.d, module-5.b-module-5.c, module-6.c. Scaffold/needs-host = module-4.b (your laptop),
module-4.c (SDK, Go+Python complete, others marked), Module 7 (k8s, needs k3d/helm), module-6.a (observability, run from
PowerShell/WSL).

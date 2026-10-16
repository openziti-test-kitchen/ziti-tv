# Drift across episodes 1 to 3

Episodes 1 to 3 live in three repositories:

| Episode | Repository |
| --- | --- |
| 1 | https://github.com/AccordionGuy/openziti-appetizer-classifier |
| 2 | https://github.com/AccordionGuy/openziti-appetizer-meets-llm-gateway |
| 3 | https://github.com/AccordionGuy/openziti-appetizer-meets-mcp-gateway |

This file records where they disagree with each other, with the Appetizer they build on, and with episode 4. It was
checked against each repository's default branch on 2026-10-16. `stack/` in this directory is the three episodes
rebuilt as one compose project, and the right-hand column says how it settles each item.

## The code agrees

Each episode adds to the last without conflicts:

- Episode 2's `classifier/` is episode 1's plus the second opinion. `Dockerfile`, `requirements.txt`
  (`openziti==1.7.1`) and `wire-up.sh` are identical. With `GATEWAY_URL` unset, episode 2's `classifier.py` behaves
  as episode 1's.
- Episode 2's `docker-compose.override.yml` is episode 1's plus `GATEWAY_URL`, `GATEWAY_KEY`, `ESCALATE_BELOW` and a
  commented `extra_hosts`.
- Episode 3's `gateway/llm-gateway.yml` is episode 2's plus the `agent` key, the `has_tools` heuristic and the
  `tools` route. Its `env.sh.example` adds `AGENT_GATEWAY_KEY`.
- Episode 3's prerequisites name episode 1's steps 1 to 7 and episode 2's steps 2 to 6 and 11, and those steps build
  what episode 3's step 1 checks for.

## Drift

| # | Where | What disagrees | Effect | In `stack/` |
| --- | --- | --- | --- | --- |
| 1 | Episode 3 `gateway/env.sh.example` | Says the agent key comes from "this exercise, step 9". The README creates it in step 10. | A reader looks in the wrong step. | Keys are in `default.env`, with the `genkey` command beside them. |
| 2 | Episodes 1 and 2 `classifier/wire-up.sh` header | Says to `docker compose cp` the script and `exec sh /tmp/wire-up.sh`. Both READMEs say to pipe it with `exec -T`, because the copied file lands unreadable by the container's user. | Following the script's own header fails. | No script. Episode 1's lab step 6 and episode 3's lab step 4 run the `ziti edge` commands one at a time. |
| 3 | Episode 2 step 3, episode 3 | Episode 2 pins LLM Gateway v0.1.7. Episode 3 needs the `has_tools` heuristic and per-key `allowed_routes`, and names no version. Episode 4 rehearsed on v0.1.8. | v0.1.7 has the heuristics router, so it works, but no README says which version episode 3 was tested on. | `runtime.Dockerfile` pins v0.1.8. |
| 4 | Episode 3 step 2, on Linux | Step 2 copies episode 3's `llm-gateway.yml` over episode 2's. It listens on `127.0.0.1:8080`, which undoes episode 2's Linux change to `172.17.0.1:8080`. Episode 3's Linux notes say to reapply it, but not that the agent then needs `LLM_GATEWAY=172.17.0.1:8080`: `agent.py` defaults to `127.0.0.1:8080`. | On Linux, either the classifier's escalations or the agent cannot reach the gateway. Neither error names the cause. | Everything reaches `llm-gateway:8080` on the compose network. |
| 5 | Episodes 2 and 3, Linux | Both Linux sections say "these changes haven't been tested". Episode 4's walkthrough used `network_mode: host` for the classifier instead of `172.17.0.1` and `extra_hosts`. | Two different Linux recipes, neither from the episodes tested. | No host networking anywhere. Tested on WSL Ubuntu. |
| 6 | Episode 2 step 4 | Ollama runs with `OLLAMA_KEEP_ALIVE=2h`, `OLLAMA_MAX_LOADED_MODELS=3`, `OLLAMA_CONTEXT_LENGTH=8192`. Episode 4's rehearsal needed `OLLAMA_KEEP_ALIVE=-1`: a cold `gemma3:4b` outran the classifier's 30 s timeout. | After two idle hours, the first escalation times out and the classifier keeps its own verdict. | The `ollama` service sets all three, with `KEEP_ALIVE=-1`. |
| 7 | Episode 3 step 4 | Installs MCP Gateway with `go install` and `CGO_ENABLED=0`. Episode 4 uses the release tarballs, and `openziti/mcp-gateway` is published on Docker Hub. | Episode 3 needs a Go toolchain only to install a binary that ships prebuilt. | `runtime.Dockerfile` installs the v0.1.11 tarball. |
| 8 | Episode 3 steps 6 and 11 | The share name is written into `agent.py` and `tools/check.py` with `sed`. Episode 4's agent reads it from `MCP_COMMAND`. | Episode 4 step 3 replaces `agent.py` and loses the edited name, so `MCP_COMMAND` has to be set. | `SHARE` in `.env`, passed as `MCP_COMMAND`. `mcp-gateway.yml` gets it at start. |
| 9 | Episode 1 step 2, episodes 2 and 3 | Ziggy enrolls through `go run clients/reflect.go` in a `golang:1.25` container. Episode 4 uses `byo/dial.py` and enrolls inside the quickstart container. | Two enrollment paths. The Go one needs a 1 GB image and a module cache. | Enrollment in the quickstart container. `dial` service for the client. |
| 10 | Episode 1 vs episode 3 | Episode 1 writes `ziti edge list terminators`, episode 3 `ziti list terminators`. Episode 3 says both work. Episode 4 needs `ziti list terminators` for the `HOST ID` column. | Cosmetic, except where the host column matters. | Not affected. |
| 11 | Episode 2 step 12 vs episode 3 step 2 | Episode 2 step 12 swaps the `subtle` route to `gemma3:27b`. Episode 3 step 2 copies a fresh `llm-gateway.yml`, which puts Claude back. | A reader who kept the swap loses it without being told. | One `llm-gateway.yml`, already episode 3's, Claude on `subtle`. Episode 2's lab step 9 swaps `subtle` to `gemma3:4b`, which is pulled, and swaps it back in the same step. `gemma3:27b` is not pulled. |
| 12 | All three | Tested on macOS with Docker Desktop. `host.docker.internal` is assumed from episode 2 on. | Linux readers hit items 4 and 5. | `stack/` does not depend on `host.docker.internal` unless `OLLAMA_URL` points at it. |

## Plan

The fixes in episode 3's repository are items 1, 4 and 8. Items 2, 3, 6 and 7 are one-line changes in episodes 1 to
3. Item 9 is a teaching choice, not a bug.

1. Decide where `stack/` is published. It replaces the "do episode 1's steps 1 to 7, then episode 2's ..." chain with
   `docker compose up -d`. Once it has a home, each episode README can link to it as the fast path to its own
   starting point.
2. Whether or not Joey's repositories change, episode 4's README states the versions it was tested with (LLM Gateway
   v0.1.8, MCP Gateway v0.1.11, openziti 1.7.1, mcp 2.3.0) and the Linux recipe it used.
3. If the episode repositories are updated: item 1 (one word), item 2 (header comment), item 4 (one line in episode
   3's Linux notes: `export LLM_GATEWAY=172.17.0.1:8080` before starting the agent), item 6 (`OLLAMA_KEEP_ALIVE=-1`
   in episode 2 step 4).

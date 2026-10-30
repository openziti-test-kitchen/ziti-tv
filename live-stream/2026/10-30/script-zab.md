# Ziti TV run sheet: Your identity, past the tunnel

Oct 30, 2026, 11 AM ET · Clint with Andrew Martinez · step numbers match [README.md](README.md)

Zone: `stillyou.dev`. Placeholders to fill from `notes/morning.md` before air: the three emails in `.env`.

## Machines

| Tag | Machine | Runs |
| --- | --- | --- |
| **[sg4]** | SG4, Windows 11, Git Bash | quickstart, wiki, ledger, `zab run` for `zab.stillyou.dev` (tunnel `zab-local`) |
| **[clintfips]** | k3s on EC2, `ssh clintfips`, `~/zab-demo` | ZAB x2, router-1, demo-http-server, whoami for `k8s.stillyou.dev` (tunnel `zab-k8s`) |
| **[brave]** | SG4 browser | one private window per person |

## Logins

| Person | Email | OpenZiti attributes | Signs in as (password: `.env` `KC_<NAME>`) | Window |
| --- | --- | --- | --- | --- |
| alice | `clint.dovholuk+alice@netfoundry.io` | `eng`, `fin` | Keycloak `alice` | browser 1 (Brave private) |
| bob | `clint.dovholuk+bob@netfoundry.io` | `eng` | Keycloak `bob` | browser 2 (Edge InPrivate) |
| carol | `clint.dovholuk+carol@netfoundry.io` | none | Keycloak `carol` | browser 3 (Chrome Guest) |
| outsider | Keycloak `dave`, not in the Access policy | | Keycloak `dave` | any browser, after the logout URL |
| OpenZiti `admin` | `.env` `ZITI_PASSWORD` | | | sg4 |

k8s: `k8s-user-full` is alice, `k8s-user-limited` is bob (same `+` addresses). Private windows in one browser share
the Cloudflare cookie: one person per browser, or open `https://zab.stillyou.dev/cdn-cgi/access/logout` between people.
Keycloak keeps its own session, so without its logout the next sign-in silently becomes the last person. To switch people
in one browser: app logout above, then
`https://zab.zititv.demo.openziti.org:9680/realms/acme/protocol/openid-connect/logout` (one Logout click), then sign in.
The team logout does not clear the app cookie. One person per browser avoids all of this.

## Links

- Walkthrough (paste in chat): <https://github.com/openziti-test-kitchen/ziti-tv/tree/main/live-stream/2026/10-30>
- Slides in `slides/`: `slide-zab-overview.svg`, `slide-zab-alice.svg`, `slide-zab-bob.svg`, `slide-zab-carol.svg`,
  `slide-zab-k8s.svg` (original: `slide-zab-architecture.svg`)
- ZAB repo: <https://github.com/openziti-test-kitchen/ziti-access-bridge>
- External JWT signers: <https://openziti.io/docs/learn/core-concepts/security/authentication/external-jwt-signers>

## Done ahead (already true at 10:30)

- [x] Cloudflare: tunnels `zab-local` and `zab-k8s`, hostnames `zab.stillyou.dev` and `k8s.stillyou.dev`, Access apps allow
  the three emails, Keycloak (realm `acme` on cdaws) is the only login method.
- [x] sg4: quickstart running, `bash setup.sh` done, wiki and ledger running, `zab run` running.
- [x] Every person has loaded both URLs once today. Then every window signed out
  (`https://<team>.cloudflareaccess.com/cdn-cgi/access/logout`).
- [x] clintfips: `kubectl -n zab-demo get pods` shows 2 zab pods Running, the matrix below passes.
- [x] alice has `eng,fin`. Re-grant takes up to five minutes, so check it before air.

**[sg4]** every new Git Bash:

```bash
cd /d/worktrees/github/openziti-test-kitchen/ziti-tv/2026-oct-30/live-stream/2026/10-30
export PATH="$PWD/bin:$PATH"
set -a; source .env; set +a
```

---

## 0. Payoff

- Same URL, three people, three answers. Nothing on the machine accepts a connection.
- **[brave]** window 1, alice: `https://zab.stillyou.dev/` → wiki greets alice, JWT verified. `/ledger/` → the Ledger.
- **[edge inprivate]** browser 2, bob: `/ledger/` → the wiki, not the ledger.
- **[chrome guest]** browser 3, carol: `https://zab.stillyou.dev/` → 403 `no route for requester`.
- All three passed Cloudflare. OpenZiti decided.
- Show `slides/slide-zab-overview.svg`.

## The last-hop gap (talk, slide up)

Andrew questions 1 to 3 below.

## 1 to 4. Build ZAB, Cloudflare, `.env`, quickstart

- Done ahead. Show the Cloudflare tunnel page: connector status Healthy, hostname `zab.stillyou.dev`.
- Show the Access app policy: three emails allowed. Point: all three pass the door.
- `cat default.env` on screen, never `.env`.

## 5. OpenZiti knows the people by email

- Walk `setup.sh` top to bottom in the editor: ZAB identity, signer, three people, two services, Bind router only.
- Point at Bind `@router-instance-1`, not `#all` (Troubleshooting entry 1, and a ZAB bug to file).

**[sg4]**

```bash
ziti edge list ext-jwt-signers
ziti edge list identities 'externalId != null'
ziti edge policy-advisor identities -q "$BOB"
```

- bob: wiki Dial Y. No ledger line at all.

## 6. Apps on loopback

**[sg4]**

```bash
# 401: nothing reaches the wiki without a Cloudflare JWT
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:$WIKI_PORT/"
netstat -ano | grep -E ":($WIKI_PORT|$LEDGER_PORT) .*LISTENING"
```

- Both on `127.0.0.1` only.

## 7. The bridge

**[sg4]**

```bash
zab --config zab/config.yml agent status
zab --config zab/config.yml agent service list
```

- `zab-v1.0.0 - supported`. Two routes on one hostname.
- Andrew questions 4 to 6.

## 8. Same URL, three people (again, slower)

- **[brave]** window 1 alice, `/` then `/ledger/`. Scroll to the JWT: issuer, aud, email.
- **[edge inprivate]** browser 2 bob `/ledger/`: wiki. bob's route table is built from what bob can see.
- **[chrome guest]** browser 3 carol: 403.
- **[any browser]** outsider (open the logout URL first): Cloudflare login refuses. ZAB never sees it.
- Andrew questions 7 to 9.

## 9. Revoke live

- alice keeps `/ledger/` open.

**[sg4]**

```bash
ziti edge update identity "$ALICE" --role-attributes eng
```

- Reload: wiki within about a second. Cloudflare unchanged.
- Re-grant now, it lands in up to five minutes, before the k8s segment ends:

**[sg4]**

```bash
ziti edge update identity "$ALICE" --role-attributes eng,fin
```

- Andrew questions 10 to 14.

## 10. ZAB with Kubernetes

- Show `slides/slide-zab-k8s.svg`.

**[clintfips]**

```bash
cd ~/zab-demo
kubectl -n zab-demo get svc,ingress
kubectl -n zab-demo get pods -o wide
kubectl -n zab-demo exec deploy/zab -- /ko-app/zab --config /etc/zab/config.yml agent status
```

- Two ClusterIP services. No ingress. Two zab pods.
- **[brave]** window 1, alice: `https://k8s.stillyou.dev/` demo page, `/whoami` shows the pod.
- Andrew: `/` 403, `/whoami` 200.
- Kill a pod, keep reloading:

**[clintfips]**

```bash
kubectl -n zab-demo delete pod "$(kubectl -n zab-demo get pod -l app=zab -o name | head -1 | cut -d/ -f2)" --wait=false
kubectl -n zab-demo get pods -w
```

- Revoke last (re-grant is slow):

**[clintfips]**

```bash
ziti edge update identity k8s-user-limited --role-attributes zab-k8s-user
```

- Andrew: `/whoami` stops answering. Andrew questions 15 to 17.

## 11. What this does not do, and what's next

- Not a Cloudflare Access replacement. No JIT provisioning here. A proof of concept at `8720108`.
- Andrew questions 18 to 22.

## Closing

- Paste the walkthrough link in chat.
- File: the Bind `#all` route bug in ziti-access-bridge.
- Next week: <topic>

---

## Andrew's questions

What we want him to land is under each. Customer specifics stay off air (see `ziti-tv-zab-plan.md` "Keep off the
stream" in the ZAB worktree).

**The last-hop gap**

1. "I've signed in to Cloudflare Access and passed policy. What does the network know about me once the request
   leaves the connector?"
   - Nothing. It's the connector's IP. Past it, IP and port firewalls.
2. "Two users with different rights come through the same tunnel. What tells them apart inside?"
   - Nothing. One shared connector identity. Least privilege ends at the edge.
3. "Why not give every app its own login and call it done?"
   - Every app becomes its own identity integration. Reachability still isn't identity-aware. Lateral movement
     stays open.

**What ZAB is**

4. "One sentence: what is ZAB?"
   - Terminates the Cloudflare tunnel, verifies the Access JWT, signs in to OpenZiti as you with that same JWT.
5. "ZAB has its own OpenZiti identity. Does traffic go out as ZAB?"
   - No. ZAB's identity finds controllers and manages config types. Every dial is the person's.
6. "How does ZAB pick the service for a request?"
   - A `zab-v1.0.0` config maps hostname plus path prefix. ZAB only sees the services the person can see, so the
     route table is already filtered by policy. That's why bob's `/ledger` lands on the wiki.

**The demo**

7. "What do I get back when I'm not allowed?"
   - 401 bad or missing JWT. 403 unknown to OpenZiti, or no route. 502 when a route exists but the dial fails.
8. "The page shows a JWT. Who signed it, and who checked it?"
   - Cloudflare signed it. ZAB verified it. OpenZiti verified it again through the signer. The app checked it a third
     time.
9. "carol passed Cloudflare. Why didn't she get in?"
   - Cloudflare answers "may this person reach the door". OpenZiti answers "which services". Two policies, two owners.
10. "I just pulled alice's attribute and her next click failed. What happened under the hood?"
    - Her next dial was refused by the controller. Revoke is about a second. Granting waits for the SDK's service
      refresh, up to five minutes. Worth being honest about.

**Signers and policy**

11. "OpenZiti didn't learn anything about Cloudflare to do this. How?"
    - External JWT signers accept any signed JWT with a known issuer and keys. ZAB is thin on top of features already
      hardened elsewhere.
12. "Does someone have to create my identity before I show up?"
    - Here, yes: `setup.sh` made them. OpenZiti 2.0 can create them on first sign-in. SCIM is the other road.
13. "We already have groups in the IdP. Do we rebuild them in OpenZiti?"
    - Claims map to attributes. Attribute-based policy expresses RBAC or anything finer.
14. "What if the token doesn't carry what you need to decide?"
    - Andrew's idea: stack extra signed documents as headers. An idea, not a feature.

**Design**

15. "ZAB keeps one SDK context per person. Why not one shared one?"
    - Auth, router connections and dials cost something. The pool reuses them across JWT rotations, closes after 30m
      idle or JWT expiry plus 5m. A pool hit is never authorization: every request re-verifies the JWT.
16. "ZAB holds everybody's JWT. Isn't ZAB now the juiciest box on the network?"
    - It can't mint tokens, only replay live ones until they expire, for the AUD it was given. Short Access session
      lifetimes bound it. Same trust you put in any reverse proxy, now with per-person policy behind it.
17. "You embedded cloudflared. Would you always want that?"
    - One binary is simple, and two replicas on one tunnel give HA for free. Teams that control their cloudflared
      provenance want a sidecar. Both have a place.

**What's next**

18. "Is this a Cloudflare thing, or could it front something else?"
    - The JWT-in-a-header pattern is common across access edges. The core is generic.
19. "OAuth assumes a human clicks Allow. Does that rule out agents?"
    - No. Nothing in the protocols needs a human.
20. "An agent I'm driving versus one that runs on its own. Same answer?"
    - The driven agent inherits my identity through ZAB. The autonomous one gets its own OpenZiti identity and
      policy. NetFoundry MCP Connect applies that model to agents and MCP servers.
21. "I set Bind to `#all` like the README says and everyone got 502s. Bug or feature?"
    - Bug. ZAB should build routes only from services the person can Dial. Filed after the show.
22. "Where is ZAB today, and what makes it production-ready?"
    - Test kitchen POC, pure Go, builds anywhere. Next: container image, sidecar mode, other access edges.

---

## If it breaks live

| Symptom | Fix |
| --- | --- |
| Cloudflare error 1033 / tunnel page shows Down | `zab run` stopped. Restart it in its terminal. |
| Everyone 403 `requester is not known to openziti` | `ziti edge list auth-policies`: signer id missing. Rerun `bash setup.sh`. |
| 502 `openziti service unreachable` | wiki or ledger process stopped, or the quickstart is down. Restart it. |
| alice still sees the ledger after revoke | Reload once more. The first request after revoke can 502, then it falls to the wiki. |
| alice doesn't get the ledger back | SDK refresh, up to five minutes. Restart `zab run` to force it. |
| k8s page down after killing a pod | `kubectl -n zab-demo get pods`: wait for Ready. The other pod should be serving. |
| Keycloak login page does not load | `ssh cdaws docker ps` for kc-acme. It serves https://zab.zititv.demo.openziti.org:9680. |

## Reset to the start

**[sg4]** stop `zab run` with Ctrl-C, then:

```bash
bash reset.sh
bash setup.sh
zab --config zab/config.yml run
```

# ZAB in Kubernetes: status (2026-10-29 night)

Cluster: `clintfips`, single node k3s v1.36.4 on EC2 (us-east-2), the NetFoundry Self-Hosted FIPS lab. Controller
`https://ctrl.clintfips.clint.demo.openziti.org:1280`, edge router `router-1` (pod `ziti-router-1`, tunnel mode
`host`). Start and stop it with `D:\worktrees\github\openziti\ziti\nf-self-hosted\selfhosted\Start-ClintFips.ps1` /
`Stop-ClintFips.ps1` (clint's shell; they need his AWS creds). Shell on the node: `ssh clintfips`; working dir
`~/zab-demo` (enrollment files, `enroll.yml`, a linux `zab` binary, and copies of these manifests in `k8s/`).

## Proven tonight

| What | Evidence |
|---|---|
| Images build without Docker | `build-images.ps1` (ko, distroless static nonroot) -> `zab.local/zab:dev`, `zab.local/demo-http-server:dev` imported with `k3s ctr` |
| Apps are ClusterIP only | `kubectl -n zab-demo get svc`: `demo-http-server` 8080, `whoami` 80, no ingress, no LB, no NodePort |
| router-1 hosts both services into the cluster | terminators for `k8s-demo` and `k8s-whoami` on router-1; a probe identity reached both through `ziti tunnel proxy`; `/echo` shows remoteAddr = router-1 pod IP |
| ZAB pods start in k8s | ConfigMap config + Secret identity + emptyDir endpoint file load cleanly; pods stop only at the (dummy) tunnel token |
| Per-user authorization through the real `zab.Bridge`, in a pod | `fakeaccess` pod (mints Access-shaped JWTs, ext-jwt-signer `fakeaccess`), results below |

```
user                  path     code  body
full@example.com      /        200   demo page
full@example.com      /whoami  200   Hostname: whoami-...
limited@example.com   /        403   no route for requester
limited@example.com   /whoami  200   Hostname: whoami-...
nobody@example.com    /        403   requester is not known to openziti
nobody@example.com    /whoami  403   requester is not known to openziti
```

Rerun it (on the node):

```bash
kubectl -n zab-demo port-forward deploy/fakeaccess 28880:28880 &
for u in full@example.com limited@example.com nobody@example.com; do for p in / /whoami; do
  printf '%-22s %-8s ' $u $p
  curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: k8s.zab.test' -H "X-As: $u" http://127.0.0.1:28880$p
done; done
```

If the fakeaccess pod restarted, its signing key changed: re-create the `fakeaccess` ext-jwt-signer from the new
JWKS (`curl -sk https://127.0.0.1:28443/cdn-cgi/access/certs` through a port-forward of 28443, x5c -> PEM) and
`ziti edge update ext-jwt-signer fakeaccess -f fakeaccess.pem`.

## What exists on the overlay

| Kind | Name | Notes |
|---|---|---|
| identity | `zab` | admin; enrolled; files in `~/zab-demo/id`, Secret `zab-identity` |
| identity | `k8s-user-full` | `#zab-k8s-user,#k8s-full`, external-id `full@example.com` (placeholder) |
| identity | `k8s-user-limited` | `#zab-k8s-user,#k8s-limited`, external-id `limited@example.com` (placeholder) |
| identity | `zab-k8s-probe` | `#k8s-full`; `~/zab-demo/probe.json`, for `ziti tunnel proxy` checks |
| config type | `zab-v1.0.0` | `zab agent register-configs` |
| service | `k8s-demo` | `#zab-k8s`; host.v1 -> `demo-http-server.zab-demo.svc.cluster.local:8080`; zab route `k8s.zab.test/` |
| service | `k8s-whoami` | `#zab-k8s`; host.v1 -> `whoami.zab-demo.svc.cluster.local:80`; zab route `k8s.zab.test/whoami`, strip prefix |
| service-policy | `k8s-bind` | Bind `#zab-k8s` to `@router-1` only (Bind `#all` would leak routes, then 502) |
| service-policy | `k8s-dial-full` | Dial `#zab-k8s` for `#k8s-full` |
| service-policy | `k8s-dial-limited` | Dial `@k8s-whoami` for `#k8s-limited` |
| edge-router-policy | `zab-k8s-users` | `#zab-k8s-user` -> `#public` |
| service-edge-router-policy | `zab-k8s` | `#zab-k8s` -> `#public` |
| ext-jwt-signer | `fakeaccess` | rehearsal only; in the `default` auth policy's allowed signers |

k8s objects in `zab-demo`: Deployments `demo-http-server`, `whoami`, `zab` (scaled to 0), `fakeaccess`; ConfigMap
`zab-config`; Secrets `zab-identity`, `zab-cloudflare-tunnel` (holds a DUMMY token).

## Morning: what needs Cloudflare and a person

Zone `stillyou.dev`, team `itsstillyou`, AUD and emails filled in below (done 2026-10-30).

Done on the node 2026-10-30 08:45 EDT: the node's `k8s/20-zab.yaml` has the team domain and AUD (not applied yet).
Signer `cloudflare-access` (id `5B5izrZE5dNeo2764pAJDB`) exists. The default auth policy allows both signers.
Both routes point at `k8s.stillyou.dev`. External-ids are set (08:59). Still to do: the token Secret, apply, and scale.

1. Cloudflare dashboard (clint):
   1. Zero Trust, Networks, Tunnels: create a named tunnel `zab-k8s`. Copy its token.
   2. On it, add public hostname `k8s.stillyou.dev` (service field does not matter).
   3. Zero Trust, Access, Applications: self-hosted app on `k8s.stillyou.dev`, policy allowing
      `clint.dovholuk+alice@netfoundry.io` and `clint.dovholuk+bob@netfoundry.io`. Copy the AUD tag and the team domain
      `itsstillyou.cloudflareaccess.com`.
2. On the node (`ssh clintfips`, then `cd ~/zab-demo`):

```bash
# tunnel token (replaces the dummy)
kubectl -n zab-demo create secret generic zab-cloudflare-tunnel --from-literal=token='<token>' \
  --dry-run=client -o yaml | kubectl apply -f -

# team domain + AUD
sed -i 's/CHANGE-ME.cloudflareaccess.com/itsstillyou.cloudflareaccess.com/; s/- CHANGE-ME/- 470e467a6e4d5f22a3dcb19a16c192ac4ee67969d2d409165186a6c75ee9ef8a/' k8s/20-zab.yaml
kubectl apply -f k8s/20-zab.yaml

# the real signer, allowed next to fakeaccess
ziti edge create ext-jwt-signer cloudflare-access https://itsstillyou.cloudflareaccess.com \
  --jwks-endpoint https://itsstillyou.cloudflareaccess.com/cdn-cgi/access/certs \
  --audience 470e467a6e4d5f22a3dcb19a16c192ac4ee67969d2d409165186a6c75ee9ef8a --claims-property email
sid() { ziti edge list ext-jwt-signers "name=\"$1\"" -j | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4; }
# repeat the flag: a comma list is stored as ONE bogus signer id
ziti edge update auth-policy default --primary-ext-jwt-allowed \
  --primary-ext-jwt-allowed-signers "$(sid fakeaccess)" --primary-ext-jwt-allowed-signers "$(sid cloudflare-access)"

# real people
ziti edge update identity k8s-user-full --external-id 'clint.dovholuk+alice@netfoundry.io'
ziti edge update identity k8s-user-limited --external-id 'clint.dovholuk+bob@netfoundry.io'

# real hostname
./zab --config enroll.yml agent service set k8s-demo --route k8s.stillyou.dev
./zab --config enroll.yml agent service set k8s-whoami --route k8s.stillyou.dev/whoami --strip-path-prefix

# go
kubectl -n zab-demo scale deploy/zab --replicas=2
kubectl -n zab-demo rollout status deploy/zab
kubectl -n zab-demo logs -l app=zab --tail=20
```

3. Optional, for the "verified JWT" page: uncomment the two `--cloudflare-*` args in `10-apps.yaml`, fill them in,
   `kubectl apply -f k8s/10-apps.yaml`. Done 2026-10-30 10:20.

Check `ziti edge list auth-policies` after step 2: both signer ids must be listed.

## Demo beats for the k8s segment

1. `kubectl -n zab-demo get svc,ingress`: two ClusterIP services, zero ingress. "How does the internet reach this?"
2. Browse `https://k8s.stillyou.dev` as `<you>`: demo page; `/whoami` shows the pod. `<them>` gets 403 on `/`, 200 on
   `/whoami`. Same URL, different person, decided by OpenZiti Service Policy, not Cloudflare.
3. `kubectl -n zab-demo exec deploy/zab -- /ko-app/zab --config /etc/zab/config.yml agent status`.
4. HA: kill ONE pod (`-l app=zab` alone kills both), keep refreshing. Both replicas hold the same tunnel;
   Cloudflare keeps routing to the survivor, and the replacement reconnects in about 2s.
   `kubectl -n zab-demo delete $(kubectl -n zab-demo get pod -l app=zab -o name | head -1) --wait=false`
5. Revoke live, as the last beat: `ziti edge update identity k8s-user-limited --role-attributes zab-k8s-user` (drop
   `k8s-limited`), the next request 403s within a second. Re-grant is slow: the Go SDK refreshes services every 5
   minutes, so to restore access sooner, re-add the attribute and `kubectl -n zab-demo rollout restart deploy/zab`.

## Proven 2026-10-30 09:05 EDT (real tunnel)

- Token Secret set, `20-zab.yaml` applied, 2 replicas Running. Each registers 4 connections to tunnel `78c14204`
  (ord/cmh edges); no errors in the logs. `readOnlyRootFilesystem: true` with `HOME=/tmp` works.
- `https://k8s.stillyou.dev/` and `/whoami` unauthenticated: 302 to `itsstillyou.cloudflareaccess.com` login.
- Kill a pod: the survivor keeps its 4 connections, and the replacement is Running in about 2s with 4 of its own.
- `agent status` inside a pod: controller live (v2.0.6), `zab-v1.0.0` supported.

## Proven 2026-10-30 10:20 EDT (browser)

- Optional step 3 is applied: `10-apps.yaml` has the team domain and AUD, and demo-http-server logs
  `verifying cloudflare access jwts for https://itsstillyou.cloudflareaccess.com`.
- Sign-in as `alice` through the Keycloak IdP (realm acme) works. `/` arrives as
  `clint.dovholuk+alice@netfoundry.io` and shows "JWT verified against https://itsstillyou.cloudflareaccess.com".
- 10:21: bob `/whoami` returns 200 with `Cf-Access-Authenticated-User-Email: clint.dovholuk+bob@netfoundry.io`.

## Not proven yet

- Access sign-in uses the Keycloak IdP (realm acme) only: `alice` and `bob`, passwords in `.env`. Still
  open: alice `/whoami` 200, bob `/` 403.
- A page load during a pod kill, from a signed-in browser.

## Teardown

```bash
kubectl delete ns zab-demo
ziti edge delete service-policies k8s-bind k8s-dial-full k8s-dial-limited
ziti edge delete edge-router-policy zab-k8s-users
ziti edge delete service-edge-router-policy zab-k8s
ziti edge delete services k8s-demo k8s-whoami
ziti edge delete configs k8s-demo.host k8s-whoami.host k8s-demo.zab-v1.0.0 k8s-whoami.zab-v1.0.0
ziti edge delete identities zab zab-k8s-probe k8s-user-full k8s-user-limited
ziti edge update auth-policy default --primary-ext-jwt-allowed=false
ziti edge delete ext-jwt-signers fakeaccess cloudflare-access
```

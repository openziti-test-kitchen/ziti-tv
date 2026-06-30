# Kubernetes: a dark service with no ingress

> NOT VERIFIED IN THIS ENVIRONMENT. k3d and helm are not installed here, so none of this has been
> run or tested. This is a self-contained scaffold for you to run later against the existing `zo`
> controller lab. Treat the values files and policy commands as a starting point and reconcile
> against the actual chart versions you pull (`helm show values openziti/ziti-router`).

## What this shows

A demo app (`traefik/whoami`) runs inside a k3d Kubernetes cluster as a **ClusterIP-only**
Service. There is no NodePort, no LoadBalancer, and no Ingress, so it is unreachable from outside
the cluster by normal means. The only way in is the OpenZiti overlay: a `ziti-host` pod inside the
cluster binds the whoami ClusterIP onto a Ziti service, and an enrolled `ziti-router` gives the
cluster a presence on the fabric. From the rest of the lab you dial `whoami.ziti` and it works,
while the app never exposes a port.

We already have a clustered controller (the `zo` lab: `ziti-controller1/2/3`, client API port
`1280`, on docker network `zo-ctrl`). So inside k8s we only add a **router** and a **host**, not a
whole new control plane.

## Pieces

| File | Purpose |
| --- | --- |
| `setup.sh` | Runs the whole sequence. Keeps all logic in the script (repo convention). |
| `manifests/whoami.yaml` | The dark app: Deployment + ClusterIP Service, nothing else. |
| `manifests/ziti-router-values.yaml` | Helm values for `ziti-router` enrolled to the existing controller. |
| `manifests/ziti-host-values.yaml` | Helm values for `ziti-host` that binds whoami onto the overlay. |
| `LESSON.md` | Short video script for the episode. |

## Prerequisites

- The `zo` controller lab is running (network `zo-ctrl` exists, controllers reachable on `1280`).
- Installed locally: `docker`, `k3d`, `kubectl`, `helm`, and the `ziti` CLI (for minting tokens).

## Run order

### 1. Create a k3d cluster on the controller's docker network

Joining `zo-ctrl` is the load-bearing trick: it lets cluster pods resolve and reach
`ziti-controller1/2/3` over the same docker network the routers already use.

```
k3d cluster create ziti --network zo-ctrl
```

### 2. Add the OpenZiti helm repo

```
helm repo add openziti https://openziti.github.io/helm-charts/
helm repo update
```

Charts: `ziti-controller`, `ziti-router`, `ziti-host`. We use the last two.

### 3. Mint a router enrollment JWT on the existing controller

The k8s edge router is just another edge router in the lab. Mint it with the tunneler enabled so
it can also host if you want it to later:

```
ziti edge create edge-router k8s-er --tunneler-enabled
```

The repo helper does the same and stages `tokens/k8s-er.{jwt,env}`:

```
scripts/mint-router-token.sh k8s-er --tunneler-enabled
```

### 4. Provision the hosted service + host identity on the controller

This mirrors `scripts/provision-echo.sh`, except the `host.v1` config points at the in-cluster
ClusterIP DNS name instead of a docker hostname:

```
ziti edge create config k8s-whoami.host.v1 host.v1 \
  '{"protocol":"tcp","address":"whoami.default.svc.cluster.local","port":80}'
ziti edge create config k8s-whoami.intercept.v1 intercept.v1 \
  '{"protocols":["tcp"],"addresses":["whoami.ziti"],"portRanges":[{"low":80,"high":80}]}'
ziti edge create service k8s-whoami --configs k8s-whoami.intercept.v1,k8s-whoami.host.v1
ziti edge create identity k8s-host -a k8s.servers -o tokens/k8s-host.jwt
ziti edge create service-policy k8s-whoami-bind Bind \
  --identity-roles '#k8s.servers' --service-roles '@k8s-whoami'
ziti edge create service-policy k8s-whoami-dial Dial \
  --identity-roles '#k8s.clients' --service-roles '@k8s-whoami'
```

Make sure edge-router and service-edge-router policies allow this service over the routers (the
lab's `erp-all` / `serp-all` from `provision-echo.sh` already cover `#all`). The dialing side is
any existing lab identity you give the `k8s.clients` attribute (for example the `echo-client`).

### 5. Install the router, deploy the dark app, install the host

```
helm install ziti-router openziti/ziti-router -n ziti --create-namespace \
  -f k8s/manifests/ziti-router-values.yaml \
  --set ctrl.endpoint=ziti-controller1:1280 \
  --set-file enrollmentJwt=tokens/k8s-er.jwt

kubectl apply -f k8s/manifests/whoami.yaml

helm install ziti-host openziti/ziti-host -n ziti --create-namespace \
  -f k8s/manifests/ziti-host-values.yaml \
  --set-file zitiEnrollment=tokens/k8s-host.jwt
```

Or just run the script, which does all of the above and checks prerequisites first:

```
ROUTER_JWT=tokens/k8s-er.jwt HOST_JWT=tokens/k8s-host.jwt bash k8s/setup.sh
```

## Verify

```
kubectl -n default get svc,ingress        # whoami: ClusterIP only, no ingress
kubectl -n ziti get pods                  # ziti-router + ziti-host running
ziti edge list edge-routers               # k8s-er shows up (on the lab side)
```

Then, from a lab identity that holds `k8s.clients`, dial `whoami.ziti:80` over Ziti and confirm
you get the whoami response. The app served traffic without ever exposing a Kubernetes ingress.

## Optional advanced step: sidecar injection webhook

Instead of a single `ziti-host` pod binding a ClusterIP, OpenZiti can inject a tunneler sidecar
into each workload pod so individual pods join the overlay directly. That is the
`ziti-host` chart's mutating-webhook / sidecar-injection mode. It is more invasive (admission
webhook, per-pod identities) and not needed for this demo, so we keep it as a follow-up. See the
chart docs: https://openziti.github.io/helm-charts/ (and the `ziti-host` chart README).

## Teardown

```
helm uninstall ziti-host ziti-router -n ziti || true
kubectl delete -f k8s/manifests/whoami.yaml || true
k3d cluster delete ziti
# optionally remove the controller-side objects:
# ziti edge delete service k8s-whoami; ziti edge delete edge-router k8s-er; ...
```

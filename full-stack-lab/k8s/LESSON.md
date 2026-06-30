# OpenZiti in Kubernetes: a dark service with no ingress (7-10 min)

**GOAL:** A normal app inside Kubernetes is reachable from the rest of the lab over the overlay,
while it exposes zero ingress, no NodePort, no LoadBalancer, nothing.

**COLD OPEN:**
> "Everyone's reflex in Kubernetes is: expose it. Slap an Ingress on it, open a NodePort, get a
> LoadBalancer. Let's do the opposite. We'll run an app with no way in at all, and still reach it
> from across the lab."

**SAY / DO:**
- SAY: "We already have a controller cluster running. The k8s cluster just joins that same docker
  network, so its pods can see the controllers." DO:
  ```
  k3d cluster create ziti --network zo-ctrl
  ```
  (point out `--network zo-ctrl`: that is the whole reason pods can reach ziti-controller1)
- SAY: "Here's our app. It's traefik/whoami, and look at the service type: ClusterIP. No ingress
  anywhere." DO:
  ```
  kubectl apply -f k8s/manifests/whoami.yaml
  kubectl -n default get svc,ingress
  ```
  (read it aloud: ClusterIP, and `No resources found` for ingress)
- SAY: "Prove it's dark. From my laptop, with the cluster's own kubeconfig, there is no URL that
  reaches it." DO: try to curl a NodePort / external IP and get nothing (there isn't one).
- SAY: "Now give the cluster a presence on the overlay. One edge router, enrolled to the existing
  controller with a token I minted on the lab side." DO:
  ```
  ziti edge create edge-router k8s-er --tunneler-enabled
  helm install ziti-router openziti/ziti-router -n ziti --create-namespace \
    -f k8s/manifests/ziti-router-values.yaml --set-file enrollmentJwt=tokens/k8s-er.jwt
  ```
- SAY: "And a host pod that binds the dark ClusterIP onto a Ziti service called k8s-whoami." DO:
  ```
  helm install ziti-host openziti/ziti-host -n ziti --create-namespace \
    -f k8s/manifests/ziti-host-values.yaml --set-file zitiEnrollment=tokens/k8s-host.jwt
  kubectl -n ziti get pods
  ```
- SAY: "Now from any allowed identity anywhere in the lab, I dial whoami.ziti, and the app answers,
  through Kubernetes, with no port ever exposed." DO: from a lab client identity:
  ```
  curl http://whoami.ziti
  ```
  (read the whoami output: it served traffic, ingress-free)
- SAY: "The app didn't change. It doesn't know Ziti exists. The overlay reached IN to a ClusterIP,
  it didn't punch a hole OUT."

**TAKEAWAY:** "A Kubernetes service can be completely dark, ClusterIP only, no ingress, and still
be reachable from anywhere on the overlay. The cluster joins the fabric with a router and a host
pod, identity and policy decide who can dial, and the workload stays exactly as it was."

**DON'T SHOW:** the sidecar-injection webhook (mention it exists for per-pod identities and move
on), chart internals, and CNI/networking plumbing beyond "the cluster is on the controller's
network."

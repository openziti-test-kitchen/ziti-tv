# Dialing the lab from your real machine (Windows / macOS / Linux)

The containerized clients live on docker networks. To dial a lab service from your actual
laptop you need (1) the controller and a public edge router reachable from the host, and (2) an
enrolled identity in a host tunneler. This is NOT verified in the build sandbox, it depends on
your machine and LAN.

## 1. Make the control plane + a router reachable

The `zo` lab already publishes controller1 on `localhost:1280` and `public-er-1` on
`localhost:3022`. For the SAME machine that runs docker, `localhost` is enough. For a different
machine on your LAN, the controller and router must advertise LAN-reachable addresses (set
`ZITI_CTRL1_ADVERTISED_ADDRESS` and the router advertised address to a hostname/IP all machines
resolve, then re-bootstrap). Per addendum_02 your machines are on one flat LAN, so the docker
host's LAN IP plus the published ports works.

## 2. Create + export an identity

```
docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y
docker exec -it zo-ziti-controller1-1 ziti edge create identity my-laptop -a echo.clients -o /tmp/my-laptop.jwt
docker cp zo-ziti-controller1-1:/tmp/my-laptop.jwt ./my-laptop.jwt
```

## 3. Enroll in a host tunneler

- Windows: Ziti Desktop Edge for Windows, add identity, point at `my-laptop.jwt`, toggle on.
- macOS: Ziti Desktop Edge for macOS, same flow. (Documented only, bring a Mac for the video.)
- Linux: `ziti-edge-tunnel enroll --jwt my-laptop.jwt --identity my-laptop.json` then
  `ziti-edge-tunnel run -i my-laptop.json`.

## 4. Dial by name

With the identity active and `echo` having an `intercept.v1` of `echo.ziti`, on the host:

```
curl http://echo.ziti
```

The Desktop Edge resolves `echo.ziti` via its own nameserver and routes it onto the overlay.
The backend stays dark, no inbound port on the host or the backend.

## Notes

- DNS: Desktop Edge manages name resolution for intercepted services automatically (unlike the
  containerized tproxy demo, which needed the resolver pointed at the tunneler).
- If the host cannot reach `public-er-1`, check the published port and any host firewall.

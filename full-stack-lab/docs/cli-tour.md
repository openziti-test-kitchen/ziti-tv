# ziti CLI tour

The actual commands this lab uses, grouped by area. Run them inside a controller container:

```
docker exec -it zo-ziti-controller1-1 ziti <args>
```

(`ziti` is at `/usr/local/bin/ziti`. Most output goes to stderr. On Git Bash, prefix in-container absolute paths
with `//`.)

## Login

```
ziti edge login localhost:1280 -u admin -p admin -y
```

## HA cluster (raft)

```
ziti agent cluster list                         # members, leader, voters, connected
ziti agent cluster add tls:ziti-controller2:1282  # add a node (run against the leader)
```

## Routers

```
ziti edge create edge-router public-er-1 --tunneler-enabled -o public-er-1.jwt   # OTT enroll token
ziti edge create edge-router transit-router -o transit-router.jwt                # transit (no tunneler)
ziti edge list edge-routers                     # ONLINE / ALLOW TRANSIT / COST
ziti fabric list routers                        # fabric view + link listeners
```

## Fabric (pathing)

```
ziti fabric list links                          # all links, latency, cost, state
ziti fabric list circuits                       # ACTIVE circuits and their PATH (r/router -> l/link -> r/router)
ziti edge list terminators                      # where each service is hosted
```

## Configs, services, policies (the echo service)

```
ziti edge create config echo.host.v1 host.v1 '{"protocol":"tcp","address":"echo-backend","port":80}'
ziti edge create config echo.intercept.v1 intercept.v1 '{"protocols":["tcp"],"addresses":["echo.ziti"],"portRanges":[{"low":80,"high":80}]}'
ziti edge create service echo --configs echo.intercept.v1,echo.host.v1

ziti edge create service-policy echo-bind Bind --identity-roles '#echo.servers' --service-roles '@echo'
ziti edge create service-policy echo-dial Dial --identity-roles '#echo.clients' --service-roles '@echo'

ziti edge create edge-router-policy erp-all --identity-roles '#all' --edge-router-roles '#all'
ziti edge create service-edge-router-policy serp-all --service-roles '#all' --edge-router-roles '#all'
```

## Identities and enrollment

```
ziti edge create identity echo-host   -a echo.servers -o echo-host.jwt     # OTT
ziti edge create identity echo-client -a echo.clients -o echo-client.jwt   # OTT
ziti edge update identity echo-client -a echo.clients,ssh.clients          # add role attributes
ziti edge list identities
```

Other enrollment methods (working):

```
ziti edge create identity alice --updb alice -a echo.clients         # UPDB (username/password)
ziti pki create ca --pki-root /pki --ca-name "3rd-party CA" --ca-file thirdparty
ziti edge create ca thirdparty-ca /pki/thirdparty/certs/thirdparty.cert --ottca --autoca --auth -a ca.enrolled
ziti edge list cas                                                    # flags: V=verified A=autoca O=ottca E=auth
```

## Posture checks (access gating)

```
ziti edge create posture-check os pc-windows --os Windows -a posture.windows
ziti edge create posture-check process ...        # process present
ziti edge create posture-check mfa ...            # client-side MFA (TOTP)
ziti edge create posture-check domain ...         # Windows domain
ziti edge create posture-check mac ...            # MAC address allowlist

# attach to a Dial policy so only compliant clients connect:
ziti edge create service-policy winonly-dial Dial \
  --identity-roles '#echo.clients' --service-roles '@winonly' \
  --posture-check-roles '#posture.windows'
```

## Router-hosted service (ssh)

```
# corp-er is a tunneler-enabled router; its router identity binds the service.
ziti edge create service-policy ssh-bind Bind --identity-roles '@corp-er' --service-roles '@ssh'
```

## Tunnelers (clients/hosts)

The `openziti/ziti-tunnel` image runs `ziti tunnel <mode>`:

```
ziti tunnel host                    # host: bind services this identity is authorized for
ziti tunnel proxy echo:8080 ssh:2222  # proxy: expose services on local ports (no tun/DNS needed)
ziti tunnel tproxy                  # tproxy: transparent intercept (needs NET_ADMIN + /dev/net/tun + DNS)
```

## Useful list filters

```
ziti edge list terminators 'service.name="echo"'
ziti edge list service-policies 'name contains "ssh"'
ziti edge list identities 'name="echo-client"'
```

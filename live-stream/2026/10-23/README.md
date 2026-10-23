# Ziti TV, October 23, 2026: Join a network with a URL and your company sign-in

Users can join an OpenZiti network with nothing but the controller's URL and their identity provider (IdP) sign-in.
Since OpenZiti 2.0, the controller can also create their identity the first time they sign in, and copy their IdP
groups into role attributes.

You end up with:

- A controller whose client API presents a Let's Encrypt certificate, so any device trusts its URL with no setup.
- **Acme**, a made-up company whose Keycloak realm has two groups: `engineering` and `finance`.
- `alice` (engineering) and `bob` (finance), who join by URL from Ziti Desktop Edge for Windows. Nobody creates
  their identities. `alice` reaches `eng-wiki`, and `bob` reaches `finance-ledger`.
- One identity as a **user session** and one as a **device certificate**, and what each leaves on the device.

This assumes you have used OpenZiti before and know what a service policy is. You need:

- A Linux machine with a public IP address, Docker, `curl`, `unzip` and `certbot`. The commands assume Ubuntu.
- A domain where you can add DNS records.
- A Windows machine with Ziti Desktop Edge for Windows 2.11.2.9 or later.
- Optionally, a Mac with Ziti Desktop Edge for macOS 2.56.593 or later, as a second machine for `alice`.

Commands tagged **[ubuntu]** run on the Linux machine. Commands tagged **[pwsh]** run in PowerShell on the Windows
machine, and **[macos]** in a terminal on the Mac. If your client machine is also Linux, it is all one shell.

The companion blog post, [Joining a network with just a
URL](https://openziti.io/blog/easier-than-ever-to-join-openziti), explains the trust model in more depth.

## 1. Get the files

**[ubuntu]**

```bash
git clone https://github.com/openziti-test-kitchen/ziti-tv.git
cd ziti-tv/live-stream/2026/10-23
cp default.env .env      # then edit .env: DOMAIN, ZITI_PWD, KC_PWD
set -a; source .env; set +a
mkdir -p "$DEMO_DIR/bin" "$DEMO_DIR/le"
```

## 2. Users type a URL, so the operating system has to trust it

A JWT carries its own trust: the tunneler checks the controller against the token and ignores the operating
system's trust store. A URL carries none. With add by URL, the tunneler downloads the network JWT only from a URL the
operating system already trusts. So the name users type needs a certificate from a public CA.

Create four DNS A records that point at this machine:

| Name | Used for |
| --- | --- |
| `addbyurl.$DOMAIN` | The URL users type. Only the Let's Encrypt certificate claims this name. |
| `addbyurl-ctrl.$DOMAIN` | The controller's control plane. Only its private PKI claims this name. |
| `addbyurl-router.$DOMAIN` | The edge router. |
| `addbyurl-idp.$DOMAIN` | Keycloak. |

Open ports 80, `$CTRL_PORT`, `$ROUTER_PORT` and `$KC_PORT` in the firewall or security group. Then get one
certificate for the two public names, and copy it where the controller and Keycloak can read it:

**[ubuntu]**

```bash
# certbot answers the HTTP-01 challenge on port 80 itself
sudo certbot certonly --standalone -d "addbyurl.$DOMAIN" -d "addbyurl-idp.$DOMAIN"
sudo cp -L "/etc/letsencrypt/live/addbyurl.$DOMAIN/fullchain.pem" \
  "/etc/letsencrypt/live/addbyurl.$DOMAIN/privkey.pem" "$DEMO_DIR/le/"
# Keycloak's container runs as uid 1000, which is the default user on an Ubuntu cloud image
sudo chown "$(id -u):$(id -g)" "$DEMO_DIR"/le/*.pem
```

The copies do not renew. Repeat the `cp` after certbot renews, and restart the controller and Keycloak.

## 3. The controller keeps its private PKI for everything else

The quickstart builds a controller and a router with their own PKI. `--configure-and-exit` writes the configuration,
enrolls the router, and stops.

**[ubuntu]**

```bash
curl -fsSL "https://github.com/openziti/ziti/releases/download/v$ZITI_VERSION/ziti-linux-amd64-$ZITI_VERSION.tar.gz" \
  | tar -xz -C "$DEMO_DIR/bin" ziti
curl -fsSL -o /tmp/zet.zip \
  https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v$ZET_VERSION/ziti-edge-tunnel-Linux_x86_64.zip
unzip -o /tmp/zet.zip -d "$DEMO_DIR/bin"
chmod +x "$DEMO_DIR/bin/ziti" "$DEMO_DIR/bin/ziti-edge-tunnel"

"$DEMO_DIR/bin/ziti" edge quickstart --configure-and-exit --home "$DEMO_DIR/qs" --password "$ZITI_PWD" \
  --ctrl-address "addbyurl-ctrl.$DOMAIN" --ctrl-port "$CTRL_PORT" \
  --router-address "addbyurl-router.$DOMAIN" --router-port "$ROUTER_PORT"
```

## 4. Three changes put the public certificate on the client API

[patch-ctrl.sh](patch-ctrl.sh) makes them and prints the diff:

1. **`edge.api.address` and the web bindPoint `address` become `addbyurl.$DOMAIN`.** During the TLS handshake the
   client sends the name it wants (SNI). The controller picks the first certificate whose DNS names match. If the
   private certificate also listed `addbyurl.$DOMAIN`, clients would get the private one. That is why the
   quickstart used a different name, `addbyurl-ctrl`.
2. **`alt_server_certs` adds the Let's Encrypt certificate.**
3. **The web listener's `ca` becomes the private root plus ISRG Root X1 and X2.** The controller serves this bundle
   at `/.well-known/est/cacerts`, and a client that enrolled with a JWT trusts that bundle and nothing else. Without
   the Let's Encrypt roots in it, the controller's own JWTs break as soon as it presents the Let's Encrypt
   certificate.

**[ubuntu]**

```bash
bash patch-ctrl.sh

A=$DEMO_DIR
nohup $A/bin/ziti controller run $A/qs/instance-1/ctrl.yaml > $A/ctrl.log 2>&1 & echo $! > $A/ctrl.pid
nohup $A/bin/ziti router run $A/qs/instance-1/router-instance-1.yaml > $A/router.log 2>&1 & echo $! > $A/router.pid

# no certificate prompt: the operating system already trusts this URL
curl -s "https://addbyurl.$DOMAIN:$CTRL_PORT/edge/client/v1/version" | head -c 200; echo
```

Test the URL from the Windows machine too. If this prints the version without a certificate error, the tunneler
will trust the URL as well:

**[pwsh]**

```powershell
# replace example.com and 9480 with your DOMAIN and CTRL_PORT
curl.exe -s https://addbyurl.example.com:9480/edge/client/v1/version
```

## 5. Acme's identity provider

Keycloak gets the same Let's Encrypt certificate. [keycloak-acme.sh](keycloak-acme.sh) creates the `acme` realm, the
`engineering` and `finance` groups, and three users. `alice` is in `engineering`, `bob` is in `finance`, and `carol`
is in no group. Each password is `<user>-demo-pw`.

It also creates `openziti`, the client the tunnelers sign in through. It is a public client with PKCE (S256) and one
redirect URI, `http://localhost:20314/auth/callback`, where the tunnelers listen for the browser to come back. Two
mappers matter: an **Audience** mapper adds `openziti` to the access token, and a **Group Membership** mapper named
`groups` has **Full group path** turned off. Then the token says `engineering` instead of `/engineering`.

**[ubuntu]**

```bash
docker run -d --name kc-acme -p "$KC_PORT:8443" -v "$DEMO_DIR/le:/le:ro" \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_PWD" \
  -e KC_HTTPS_CERTIFICATE_FILE=/le/fullchain.pem -e KC_HTTPS_CERTIFICATE_KEY_FILE=/le/privkey.pem \
  -e KC_HOSTNAME="https://addbyurl-idp.$DOMAIN:$KC_PORT" \
  "quay.io/keycloak/keycloak:$KEYCLOAK_VERSION" start-dev

# wait for "Running the server in development mode", then build the realm
docker logs -f kc-acme
bash keycloak-acme.sh
```

## 6. IdP groups become OpenZiti role attributes

[ziti-setup.sh](ziti-setup.sh) creates the external JWT signer, the `idp-users` auth policy, and the two services,
each backed by a `traefik/whoami` container. The signer's flags do the work:

- `--claims-property email`: an identity's `externalId` is the user's email.
- `--enroll-to-token --enroll-to-cert`: a user who can sign in can enroll, and the controller creates the identity.
  These are **Auto-Enroll to Token** and **Auto-Enroll to Cert** in the Ziti Admin Console.
- `--enroll-name-claims-selector preferred_username`: the identity is named after the Keycloak username.
- `--enroll-attr-claims-selector groups`: the `groups` claim becomes the identity's role attributes.

The dial policies are written against `#engineering` and `#finance`, names that only exist in Keycloak so far.

**[ubuntu]**

```bash
docker run -d --name whoami-eng -p 127.0.0.1:9781:80 traefik/whoami
docker run -d --name whoami-fin -p 127.0.0.1:9782:80 traefik/whoami

"$DEMO_DIR/bin/ziti" edge login "addbyurl.$DOMAIN:$CTRL_PORT" -u admin -p "$ZITI_PWD"
bash ziti-setup.sh

# the host identity enrolls with a JWT, against the Let's Encrypt certificate; this is the bundle from step 4 at work
A=$DEMO_DIR
mkdir -p $A/host-ids
$A/bin/ziti-edge-tunnel enroll -j $A/acme-host.jwt -i $A/host-ids/acme-host.json
# run-host only hosts services, so it needs no root and no tun device
nohup $A/bin/ziti-edge-tunnel run-host -i $A/host-ids/acme-host.json > $A/host.log 2>&1 & echo $! > $A/host.pid

"$DEMO_DIR/bin/ziti" edge list identities
```

Only `acme-host` and the admin exist. There is no `alice` and no `bob`.

## 7. alice joins with a URL and a user session

In Ziti Desktop Edge for Windows, click **ADD IDENTITY**, then **With URL**, and enter
`https://addbyurl.$DOMAIN:$CTRL_PORT`. The tunneler finds the controller's identity provider and asks which way to
enroll. Pick **User session**. The browser opens Keycloak. Sign in as `alice` with `alice-demo-pw`.

**[pwsh]**

```powershell
curl.exe -s http://eng-wiki.acme.ziti          # whoami answers
curl.exe -s -m 5 http://finance-ledger.acme.ziti   # no answer: alice has no access
```

**[ubuntu]**

```bash
"$DEMO_DIR/bin/ziti" edge list identities
"$DEMO_DIR/bin/ziti" edge policy-advisor identities -q alice
```

`alice` exists now, with the attribute `engineering` and the auth policy `idp-users`. Nobody ran
`ziti edge create identity`. A user session leaves controller URLs and a CA bundle on the device, and no key. Every
new session comes from an IdP sign-in, so disabling `alice` in Keycloak stops her next sign-in.

## 8. bob joins with a device certificate

Keycloak remembers `alice`'s browser session, and would sign `bob` in as `alice`. Sign out first at
`https://addbyurl-idp.$DOMAIN:$KC_PORT/realms/acme/account`.

Add by URL again, pick **Device certificate**, and sign in as `bob` with `bob-demo-pw`.

**[pwsh]**

```powershell
curl.exe -s http://finance-ledger.acme.ziti    # whoami answers
```

**[ubuntu]**

```bash
"$DEMO_DIR/bin/ziti" edge policy-advisor identities -q bob
```

A device certificate leaves a private key and a certificate on the device. `bob` signs in to Keycloak once, and the
identity then authenticates with its certificate. It comes up with nobody signed in and keeps working when Keycloak
is down. Disabling `bob` in Keycloak does not stop it; disable or delete the identity in OpenZiti.

Each user gets one device certificate identity. **Forget** removes it from the device, not from the controller, so
adding it again, or moving it to another machine, needs an administrator first:

**[ubuntu]**

```bash
"$DEMO_DIR/bin/ziti" edge delete identity bob
```

A user session has no such limit. Add `alice` by URL on a second machine, and she signs in as the identity she
already has. The controller still has one `alice`.

On a Mac, Ziti Desktop Edge for macOS 2.56.593 and later adds by URL the same way. Add an identity with the URL
`https://addbyurl.$DOMAIN:$CTRL_PORT`, pick **User session**, and sign in as `alice`. On macOS, a device certificate's
private key goes in the keychain, not in a file.

**[macos]**

```bash
curl -s http://eng-wiki.acme.ziti              # whoami answers, on the second machine too
```

**[ubuntu]**

```bash
# still one alice, and no new identity was created
"$DEMO_DIR/bin/ziti" edge list identities
```

## 9. Groups are copied once

The controller reads the `groups` claim when it creates the identity, and never again. Add `alice` to `finance` in
Keycloak, and her identity keeps only `engineering` until an administrator changes it. `carol` is in no group, so
Keycloak leaves the `groups` claim out of her token. She can still enroll, gets no attributes, and matches neither
dial policy.

## 10. The same from the Linux command line

On a Linux desktop with a browser, `ziti-edge-tunnel` adds by URL from the command line. With `ziti-edge-tunnel run`
already running, `add` joins the network and `ext-jwt-login` returns the IdP URL to open in the browser. It does not
open one itself. `-m token` is a user session, `-m cert` a device certificate.

**[ubuntu]**

```bash
CTRL_URL=https://addbyurl.example.com:9480     # your DOMAIN and CTRL_PORT
sudo ziti-edge-tunnel add -i carol -u "$CTRL_URL" -m token
sudo ziti-edge-tunnel ext-jwt-login -i carol -p acme-idp
```

`ziti-edge-tunnel enroll` does the same without a running tunneler, and writes the identity file:

```bash
ziti-edge-tunnel enroll --url "$CTRL_URL" --enroll-to token --provider acme-idp -i carol.json
```

## Reset and tear down

**[ubuntu]**

```bash
# alice, bob and carol are gone from OpenZiti and signed out of Keycloak, and alice is in engineering only again.
# Everything else stays up: start again at step 7.
bash reset.sh

# everything this walkthrough started is gone, except the Let's Encrypt copies in $DEMO_DIR/le: start again at step 3
bash reset.sh all

# and the certificate too
rm -rf "$DEMO_DIR"
```

In Ziti Desktop Edge, **Forget** each identity.

## Troubleshooting

**The tunneler or `curl` rejects the certificate for `addbyurl.$DOMAIN`.** The controller presented its private
certificate. It picks the first certificate whose DNS names match the name the client asked for, so if the private
certificate also lists `addbyurl.$DOMAIN`, the private one wins. Keep the quickstart's `--ctrl-address` a different
name, as in step 3.

**JWT enrollment fails with `CONTROLLER_UNAVAILABLE` after the switch to Let's Encrypt.** The token checks out, then
the next request fails: the client trusts only the controller's CA bundle, and the bundle has no Let's Encrypt root.
Run `patch-ctrl.sh` again, check that `web-ca-bundle.pem` holds three certificates, and restart the controller.

**Add by URL against `addbyurl-ctrl.$DOMAIN` fails with `CONTROLLER_UNAVAILABLE`.** That name has only the private
certificate, which the operating system does not trust. That is the refusal working as intended. Use
`addbyurl.$DOMAIN`.

**`ext-jwt-login` fails with `failed to start external auth`.** The first login on a new tunneler needs `-p` with the
signer name, even when the controller has only one signer. Later logins work without it.

**`add ... -m token` fails with `ENROLLMENT_IDENTITY_ALREADY_ENROLLED`.** The user already has an identity. Leave
`-m` off, then `ext-jwt-login` signs in as the existing identity.

**`ziti edge` commands fail with `CLUSTER_NO_LEADER` right after a controller restart.** The controller has not
elected itself leader yet. Wait a few seconds and run the command again.

**`ziti edge delete ext-jwt-signer acme-idp` fails.** The `idp-users` auth policy still references it. Delete the
policy first.

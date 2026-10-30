# Ziti TV run sheet: Joining a network with just a URL

Oct 23, 2026, 11 AM ET · Clint · step numbers match [README.md](README.md)

## Machines

| Tag | Machine | Runs |
| --- | --- | --- |
| **[cdaws]** | cdaws (3.18.113.172) | Payoff overlay (`~/payoff`), live overlay (`~/addbyurl`), both Keycloaks |
| **[sg4]** | SG4, Windows 11 | ZDEW: `dave`, then `alice`. `ziti-edge-tunnel -P ziti-tv`: `carol` |
| **[claudevm]** | claudevm, Windows 11 | ZDEW: `bob` |
| **[macos]** | M1 mini over VNC | ZDEW for macOS: `alice` |

## Two overlays

| Overlay | URL users type | Keycloak | Files on cdaws | Use |
| --- | --- | --- | --- | --- |
| Payoff | `https://addbyurl.zititv.demo.openziti.org:9580` | `:9780` | `~/payoff`, `~/payoff-10-23` | Opening only, already running |
| Live | `https://addbyurl.zititv.demo.openziti.org:9480` | `:9680` | `~/addbyurl`, `~/ziti-tv-10-23` | Built on stream, steps 1–10 |

## Logins

| User | Password | Group | Where | Mode |
| --- | --- | --- | --- | --- |
| `dave` | `dave-demo-pw` | `engineering` | SG4, payoff overlay | User session |
| `alice` | `alice-demo-pw` | `engineering` | SG4, then M1 mini | User session |
| `bob` | `bob-demo-pw` | `finance` | claudevm | Device certificate |
| `carol` | `carol-demo-pw` | none | SG4 `-P ziti-tv` | User session |
| Ziti `admin` | `ZITI_PWD` in `.env` | | cdaws | |
| Keycloak `admin` | `KC_PWD` in `.env` | | realm `master` | |

## Links

- Walkthrough (paste in chat): <https://github.com/openziti-test-kitchen/ziti-tv/tree/main/live-stream/2026/10-23>
- README: <https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md>
- Diagrams, on screen: <file:///D:/tmp/ziti-tv-script/diagrams.html>
- Diagrams, GitHub: <https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/diagrams.md>
- Live controller: <https://addbyurl.zititv.demo.openziti.org:9480/edge/client/v1/version>
- Live Keycloak admin: <https://addbyurl-idp.zititv.demo.openziti.org:9680/admin/master/console/#/acme/groups>
- Live Keycloak sign-out: <https://addbyurl-idp.zititv.demo.openziti.org:9680/realms/acme/account>
- Payoff Keycloak sign-out: <https://addbyurl-idp.zititv.demo.openziti.org:9780/realms/acme/account>
- YouTube live: <https://youtube.com/live/VMg5y1V1eDs>
- Docs, external JWT signers: <https://openziti.io/docs/learn/core-concepts/security/authentication/external-jwt-signers>
- Docs, add by URL in ZDEW: <https://openziti.io/docs/how-to-guides/tunnelers/windows/add-ids/ext-providers/ext-jwt-url>

## Before going live

- [ ] Every ZDEW: **Forget** any `addbyurl` identity
- [ ] `ipconfig /flushdns` on SG4 and claudevm, `sudo killall -HUP mDNSResponder` on the Mac
- [ ] Every browser signed out of `addbyurl-idp`
- [ ] cdaws terminal in `~/ziti-tv-10-23` with `.env` loaded. If not:

```bash
cd ~/ziti-tv-10-23
set -a; source .env; set +a
```

---

## 0. Opening: the payoff

- join with a URL and your company login, no JWT in an email
- Show the join diagram: <file:///D:/tmp/ziti-tv-script/diagrams.html>
- **[sg4]** ZDEW → **ADD IDENTITY** → **With URL** → payoff URL, port **9580**:

```text
https://addbyurl.zititv.demo.openziti.org:9580
```

- **User session** → `dave` / `dave-demo-pw`
- **[sg4]**

```powershell
curl.exe -s http://eng-wiki.acme.ziti
```

- Payoff overlay was built before the show in `~/payoff` (ports 9580/9590/9780); the live one is empty
- **[sg4]** ZDEW → **Forget** dave. Browser → sign out:

```text
https://addbyurl-idp.zititv.demo.openziti.org:9780/realms/acme/account
```

- Acme, Keycloak, alice = engineering, bob = finance, carol = nothing

## 1. Files

- README: [step 1](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#1-get-the-files)
- **[cdaws]**

```bash
ls
mkdir -p "$DEMO_DIR/bin"
```

- Done: episode files copied to `~/ziti-tv-10-23`, `.env` made from `default.env` (domain, two passwords, ports)

## 2. Certificate

- README: [step 2](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#2-users-type-a-url-so-the-operating-system-has-to-trust-it)
- **[cdaws]**

```bash
ls -la "$DEMO_DIR/le"
openssl x509 -in "$DEMO_DIR/le/fullchain.pem" -noout -subject -enddate
```

- Done before the show: wildcard `*.zititv.demo.openziti.org` from Let's Encrypt (certbot, DNS-01), valid until Dec 2, copied to `$DEMO_DIR/le`
- Why: a JWT carries its own trust; a URL only works if the OS already trusts the cert
- Show README step 2 DNS table, `addbyurl` is the only name users type

## 3. Download, quickstart

- README: [step 3](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#3-the-controller-keeps-its-private-pki-for-everything-else)
- **[cdaws]**

```bash
curl -fsSL "https://github.com/openziti/ziti/releases/download/v$ZITI_VERSION/ziti-linux-amd64-$ZITI_VERSION.tar.gz" \
  | tar -xz -C "$DEMO_DIR/bin" ziti
curl -fsSL -o /tmp/zet.zip \
  https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v$ZET_VERSION/ziti-edge-tunnel-Linux_x86_64.zip
unzip -o /tmp/zet.zip -d "$DEMO_DIR/bin"
chmod +x "$DEMO_DIR/bin/ziti" "$DEMO_DIR/bin/ziti-edge-tunnel"
```

- **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge quickstart --configure-and-exit --home "$DEMO_DIR/qs" --password "$ZITI_PWD" \
  --ctrl-address "addbyurl-ctrl.$DOMAIN" --ctrl-port "$CTRL_PORT" \
  --router-address "addbyurl-router.$DOMAIN" --router-port "$ROUTER_PORT"
```

- Point at `addbyurl-ctrl`: not `addbyurl`, matters in step 4

## 4. Patch, start

- README: [step 4](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#4-one-change-puts-the-public-certificate-on-the-client-api)
- **[cdaws]**

```bash
bash patch-ctrl.sh
```

- Walk the diff:
  - `alt_server_certs` → Let's Encrypt cert (picked by SNI for `addbyurl`)
  - client API address stays `addbyurl-ctrl`
  - CA bundle untouched: never add a public root to it
- **[cdaws]**

```bash
A=$DEMO_DIR
nohup $A/bin/ziti controller run $A/qs/instance-1/ctrl.yaml > $A/ctrl.log 2>&1 & echo $! > $A/ctrl.pid
nohup $A/bin/ziti router run $A/qs/instance-1/router-instance-1.yaml > $A/router.log 2>&1 & echo $! > $A/router.pid
```

- **[sg4]**

```powershell
curl.exe -s https://addbyurl.zititv.demo.openziti.org:9480/edge/client/v1/version
```

- Result: no `-k`, no cert prompt, the OS trusts the URL

## 5. Keycloak

- README: [step 5](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#5-acmes-identity-provider)
- **[cdaws]**

```bash
docker run -d --name kc-acme -p "$KC_PORT:8443" -v "$DEMO_DIR/le:/le:ro" \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_PWD" \
  -e KC_HTTPS_CERTIFICATE_FILE=/le/fullchain.pem -e KC_HTTPS_CERTIFICATE_KEY_FILE=/le/privkey.pem \
  -e KC_HOSTNAME="https://addbyurl-idp.$DOMAIN:$KC_PORT" \
  "quay.io/keycloak/keycloak:$KEYCLOAK_VERSION" start-dev
```

- **[cdaws]** wait for `Running the server in development mode` (about 45 s), Ctrl+C

```bash
docker logs -f kc-acme
```

- **[cdaws]**

```bash
bash keycloak-acme.sh
```

- two groups, users, watch carol
- Audience mapper → `openziti` in the token
- `groups` mapper, full path off → `engineering` not `/engineering`
- Optional, **[sg4]** browser, Keycloak `admin`:

```text
https://addbyurl-idp.zititv.demo.openziti.org:9680/admin/master/console/#/acme/groups
```

## 6. Signer, policies, services

- README: [step 6](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#6-idp-groups-become-openziti-role-attributes)
- **[cdaws]**

```bash
docker run -d --name whoami-eng -p 127.0.0.1:9781:80 traefik/whoami
docker run -d --name whoami-fin -p 127.0.0.1:9782:80 traefik/whoami

"$DEMO_DIR/bin/ziti" edge login "addbyurl.$DOMAIN:$CTRL_PORT" -u admin -p "$ZITI_PWD"
bash ziti-setup.sh
```

- Read the signer flags:
  - `--claims-property email` → `externalId` is the email
  - `--enroll-to-token --enroll-to-cert` → anyone who signs in can enroll
  - `--enroll-name-claims-selector preferred_username` → identity named after the user
  - `--enroll-attr-claims-selector groups` → groups become attributes
- policies say `#engineering`, `#finance`, nobody has them yet
- **[cdaws]**

```bash
A=$DEMO_DIR
mkdir -p $A/host-ids
$A/bin/ziti-edge-tunnel enroll -j $A/acme-host.jwt -i $A/host-ids/acme-host.json
nohup $A/bin/ziti-edge-tunnel run-host -i $A/host-ids/acme-host.json > $A/host.log 2>&1 & echo $! > $A/host.pid

"$DEMO_DIR/bin/ziti" edge list identities
```

- `acme-host` used a plain JWT, JWTs still work
- only `acme-host` and admin, no alice, no bob

## 7. alice, user session

- README: [step 7](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#7-alice-joins-with-a-url-and-a-user-session)
- **[sg4]** ZDEW → **ADD IDENTITY** → **With URL** → live URL, port **9480**:

```text
https://addbyurl.zititv.demo.openziti.org:9480
```

- **User session** → `alice` / `alice-demo-pw`
- **[sg4]**

```powershell
curl.exe -s http://eng-wiki.acme.ziti
curl.exe -s -m 5 http://finance-ledger.acme.ziti
```

- **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge list identities
"$DEMO_DIR/bin/ziti" edge policy-advisor identities -q alice
```

- nobody ran `create identity`
- no key on the laptop, disable alice in Keycloak and she's out

## 8. bob, device certificate

- README: [step 8](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#8-bob-joins-with-a-device-certificate)
- **[claudevm]** ZDEW → **ADD IDENTITY** → **With URL**

```text
https://addbyurl.zititv.demo.openziti.org:9480
```

- **Device certificate** → `bob` / `bob-demo-pw`
- **[claudevm]**

```powershell
curl.exe -s http://finance-ledger.acme.ziti
```

- **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge policy-advisor identities -q bob
```

- key on the device, works with Keycloak down
- disabling bob in Keycloak does not stop him, disable in OpenZiti
- one device cert per user, **Forget** doesn't remove it from the controller
- Optional **[cdaws]**:

```bash
"$DEMO_DIR/bin/ziti" edge delete identity bob
```

### alice on the Mac

- **[macos]** ZDEW → add identity with URL

```text
https://addbyurl.zititv.demo.openziti.org:9480
```

- **User session** → `alice` / `alice-demo-pw`
- **[macos]**

```bash
curl -s http://eng-wiki.acme.ziti
```

- **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge list identities
```

- second machine, still one alice

## 9. Groups copied once

- README: [step 9](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#9-groups-are-copied-once)
- groups read at creation only, then an admin owns attributes
- Optional: Keycloak console → add alice to `finance` → **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge list identities
```

- alice still says engineering

## 10. carol, command line

- README: [step 10](https://github.com/openziti-test-kitchen/ziti-tv/blob/main/live-stream/2026/10-23/README.md#10-the-same-from-the-linux-command-line)
- **[sg4]** browser: sign out of alice

```text
https://addbyurl-idp.zititv.demo.openziti.org:9680/realms/acme/account
```

- **[sg4]**

```powershell
$zet = 'D:\tmp\ziti-tv-zet\1.19.1\ziti-edge-tunnel.exe'
$ctrl = 'https://addbyurl.zititv.demo.openziti.org:9480'
& $zet add -P ziti-tv -i carol -u $ctrl -m token
& $zet ext-jwt-login -P ziti-tv -i carol -p acme-idp
```

- Open the printed URL → `carol` / `carol-demo-pw`
- **[sg4]**

```powershell
& $zet dump -P ziti-tv
```

- **[cdaws]**

```bash
"$DEMO_DIR/bin/ziti" edge list identities
```

- `-m token` = user session, `-m cert` = device cert
- first login needs `-p <signer>`, same on Linux with `sudo`
- carol exists, no attributes, reaches nothing
- Don't `curl` from SG4: alice's ZDEW answers those names

## Closing

- a URL and a sign-in, identity at first login, access from IdP groups
- user session for people, device cert for machines
- Paste in chat: <https://github.com/openziti-test-kitchen/ziti-tv/tree/main/live-stream/2026/10-23>

---

## If it breaks

| Symptom | Fix |
| --- | --- |
| `CLUSTER_NO_LEADER` | Wait a few seconds, retry |
| Tunneler rejects the `addbyurl` cert | `--ctrl-address` must be `addbyurl-ctrl` |
| JWT enroll `CONTROLLER_UNAVAILABLE` | Rerun `patch-ctrl.sh`, restart controller |
| bob or carol signs in as alice | Sign out at `/realms/acme/account` |
| `failed to start external auth` | `ext-jwt-login` needs `-p acme-idp` |
| `ENROLLMENT_IDENTITY_ALREADY_ENROLLED` | Drop `-m`, run `ext-jwt-login` |
| Service does not answer | `tail $DEMO_DIR/host.log` |

## Reset

- Users only, restart at step 7 → **[cdaws]** `bash reset.sh`
- Everything but the cert, restart at step 1 → **[cdaws]** `bash reset.sh all`
- Then **Forget** in every ZDEW
- The payoff overlay is separate: `~/payoff-10-23/reset.sh` resets it

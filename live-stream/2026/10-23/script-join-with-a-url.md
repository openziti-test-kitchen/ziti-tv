# Ziti TV run sheet: Joining a network with just a URL

Oct 23, 2026, 11 AM ET · Clint

Step numbers match [README.md](README.md). Do each line in order. **Say** lines are optional talking points.

## Machines

| Tag | Machine | What runs there |
| --- | --- | --- |
| **[cdaws]** | cdaws (3.18.113.172) | Controller, router, Keycloak, `acme-host`, whoami-eng, whoami-fin |
| **[sg4]** | SG4, Windows 11 | ZDEW: `alice`. Second `ziti-edge-tunnel`, `-P ziti-tv`: `carol` |
| **[claudevm]** | claudevm, Windows 11 | ZDEW: `bob` |
| **[macos]** | M1 mini over VNC | ZDEW for macOS: `alice` again |

## Logins

The URL users type:

```text
https://addbyurl.zititv.demo.openziti.org:9480
```

| User | Password | Group | Joins on | Mode | Reaches |
| --- | --- | --- | --- | --- | --- |
| `alice` | `alice-demo-pw` | `engineering` | SG4 ZDEW, then M1 mini | User session | `eng-wiki.acme.ziti` |
| `bob` | `bob-demo-pw` | `finance` | claudevm ZDEW | Device certificate | `finance-ledger.acme.ziti` |
| `carol` | `carol-demo-pw` | none | SG4 `ziti-edge-tunnel -P ziti-tv` | User session | nothing |
| `dave` | `dave-demo-pw` | `engineering` | SG4 ZDEW, opening only | User session | `eng-wiki.acme.ziti` |

| Admin login | User | Password |
| --- | --- | --- |
| OpenZiti controller | `admin` | `ZITI_PWD` in `~/ziti-tv-10-23/.env` |
| Keycloak admin console, realm `master` | `admin` | `KC_PWD` in `~/ziti-tv-10-23/.env` |

Off screen only, to read a password:

```bash
grep KC_PWD ~/ziti-tv-10-23/.env
```

## Before going live

- [x] Wildcard cert `*.zititv.demo.openziti.org` (valid until Dec 2) in `~/addbyurl/le/`.
- [x] DNS: `addbyurl`, `addbyurl-ctrl`, `addbyurl-router`, `addbyurl-idp` under `zititv.demo.openziti.org`.
- [x] Security group opens 9480, 9490, 9680.
- [x] Episode files in `~/ziti-tv-10-23` on cdaws, with `.env`. Never `cat` `.env` on screen.
- [ ] Every ZDEW: **Forget** any `addbyurl` identity.
- [ ] **[sg4]** and **[claudevm]**: `ipconfig /flushdns`. **[macos]**: `sudo killall -HUP mDNSResponder`.
- [ ] Every browser: signed out of `addbyurl-idp`.
- [ ] Walkthrough link ready to paste in chat.

Every new cdaws terminal opens in `~/ziti-tv-10-23` with `.env` loaded. If one does not:

```bash
cd ~/ziti-tv-10-23
set -a; source .env; set +a
```

---

## 0. Opening: dave joins a pre-built network

Off screen before going live: run steps 3 to 6 on cdaws.

1. **Say:** a user joins with a URL and their company login. No JWT in an email.
2. **[sg4]** ZDEW: **ADD IDENTITY** → **With URL** → paste:

   ```text
   https://addbyurl.zititv.demo.openziti.org:9480
   ```

3. Pick **User session**. Sign in as `dave` / `dave-demo-pw`.
4. **[sg4]** Paste:

   ```powershell
   curl.exe -s http://eng-wiki.acme.ziti
   ```

5. **Say:** that's the payoff. Now we build it from nothing.
6. **[sg4]** ZDEW: **Forget** dave. Browser: sign out at
   `https://addbyurl-idp.zititv.demo.openziti.org:9680/realms/acme/account`.
7. **[cdaws]** Paste:

   ```bash
   bash reset.sh all
   ```

8. Show the top of the README. **Say:** Acme is the company, Keycloak is its IdP. alice is engineering, bob is
   finance, carol is in nothing.

## 1. Get the files

1. **[cdaws]** Paste:

   ```bash
   ls
   mkdir -p "$DEMO_DIR/bin"
   ```

2. **Say:** it's all in the ziti-tv repo. Copy `default.env` to `.env`, fill in a domain and two passwords.

## 2. The certificate

1. **[cdaws]** Paste:

   ```bash
   ls -la "$DEMO_DIR/le"
   openssl x509 -in "$DEMO_DIR/le/fullchain.pem" -noout -subject -enddate
   ```

2. **Say:** baked ahead with certbot. A JWT carries its own trust. A URL needs the OS to trust it, so it needs a public
   cert.
3. Show the DNS table in README step 2. Point at `addbyurl`: the only name users type.

## 3. Download and quickstart

1. **[cdaws]** Paste:

   ```bash
   curl -fsSL "https://github.com/openziti/ziti/releases/download/v$ZITI_VERSION/ziti-linux-amd64-$ZITI_VERSION.tar.gz" \
     | tar -xz -C "$DEMO_DIR/bin" ziti
   curl -fsSL -o /tmp/zet.zip \
     https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v$ZET_VERSION/ziti-edge-tunnel-Linux_x86_64.zip
   unzip -o /tmp/zet.zip -d "$DEMO_DIR/bin"
   chmod +x "$DEMO_DIR/bin/ziti" "$DEMO_DIR/bin/ziti-edge-tunnel"
   ```

2. **[cdaws]** Paste:

   ```bash
   "$DEMO_DIR/bin/ziti" edge quickstart --configure-and-exit --home "$DEMO_DIR/qs" --password "$ZITI_PWD" \
     --ctrl-address "addbyurl-ctrl.$DOMAIN" --ctrl-port "$CTRL_PORT" \
     --router-address "addbyurl-router.$DOMAIN" --router-port "$ROUTER_PORT"
   ```

3. Point at `--ctrl-address addbyurl-ctrl`. **Say:** not `addbyurl`. That matters in step 4.

## 4. Patch the controller, start it

1. **[cdaws]** Paste:

   ```bash
   bash patch-ctrl.sh
   ```

2. Walk the diff it prints, three changes:
   1. Client API address becomes `addbyurl`. The controller picks a cert by SNI.
   2. `alt_server_certs` adds the Let's Encrypt cert.
   3. CA bundle gets ISRG Root X1 and X2, so JWT enrollments still work.
3. **[cdaws]** Paste:

   ```bash
   A=$DEMO_DIR
   nohup $A/bin/ziti controller run $A/qs/instance-1/ctrl.yaml > $A/ctrl.log 2>&1 & echo $! > $A/ctrl.pid
   nohup $A/bin/ziti router run $A/qs/instance-1/router-instance-1.yaml > $A/router.log 2>&1 & echo $! > $A/router.pid
   ```

4. **[sg4]** Paste:

   ```powershell
   curl.exe -s https://addbyurl.zititv.demo.openziti.org:9480/edge/client/v1/version
   ```

5. **Say:** no `-k`, no cert prompt. The OS trusts this URL. That's the whole trick.

## 5. Keycloak

1. **[cdaws]** Paste:

   ```bash
   docker run -d --name kc-acme -p "$KC_PORT:8443" -v "$DEMO_DIR/le:/le:ro" \
     -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_PWD" \
     -e KC_HTTPS_CERTIFICATE_FILE=/le/fullchain.pem -e KC_HTTPS_CERTIFICATE_KEY_FILE=/le/privkey.pem \
     -e KC_HOSTNAME="https://addbyurl-idp.$DOMAIN:$KC_PORT" \
     "quay.io/keycloak/keycloak:$KEYCLOAK_VERSION" start-dev
   ```

2. **[cdaws]** Paste. Wait for `Running the server in development mode`, then Ctrl+C:

   ```bash
   docker logs -f kc-acme
   ```

3. **[cdaws]** Paste:

   ```bash
   bash keycloak-acme.sh
   ```

4. **Say:** two groups, three users. Watch carol, she's the edge case.
5. **Say:** two mappers matter. Audience puts `openziti` in the token. `groups` with Full group path off gives
   `engineering`, not `/engineering`.
6. Optional, **[sg4]** browser, log in as Keycloak `admin`:

   ```text
   https://addbyurl-idp.zititv.demo.openziti.org:9680/admin/master/console/#/acme/groups
   ```

## 6. Signer, policies, services

1. **[cdaws]** Paste:

   ```bash
   docker run -d --name whoami-eng -p 127.0.0.1:9781:80 traefik/whoami
   docker run -d --name whoami-fin -p 127.0.0.1:9782:80 traefik/whoami

   "$DEMO_DIR/bin/ziti" edge login "addbyurl.$DOMAIN:$CTRL_PORT" -u admin -p "$ZITI_PWD"
   bash ziti-setup.sh
   ```

2. Read out the four signer flags:
   - `--claims-property email`: `externalId` is the email.
   - `--enroll-to-token --enroll-to-cert`: anyone who can sign in can enroll.
   - `--enroll-name-claims-selector preferred_username`: identity named after the Keycloak user.
   - `--enroll-attr-claims-selector groups`: groups become role attributes.
3. **Say:** the dial policies say `#engineering` and `#finance`. Nobody has those attributes yet.
4. **[cdaws]** Paste:

   ```bash
   A=$DEMO_DIR
   mkdir -p $A/host-ids
   $A/bin/ziti-edge-tunnel enroll -j $A/acme-host.jwt -i $A/host-ids/acme-host.json
   nohup $A/bin/ziti-edge-tunnel run-host -i $A/host-ids/acme-host.json > $A/host.log 2>&1 & echo $! > $A/host.pid

   "$DEMO_DIR/bin/ziti" edge list identities
   ```

5. **Say:** `acme-host` enrolled with a plain JWT, so JWTs still work. The list has only `acme-host` and admin. No
   alice, no bob.

## 7. alice, user session

1. **[sg4]** ZDEW: **ADD IDENTITY** → **With URL** → paste:

   ```text
   https://addbyurl.zititv.demo.openziti.org:9480
   ```

2. Pick **User session**. Sign in as `alice` / `alice-demo-pw`.
3. **[sg4]** Paste:

   ```powershell
   curl.exe -s http://eng-wiki.acme.ziti
   curl.exe -s -m 5 http://finance-ledger.acme.ziti
   ```

4. **[cdaws]** Paste:

   ```bash
   "$DEMO_DIR/bin/ziti" edge list identities
   "$DEMO_DIR/bin/ziti" edge policy-advisor identities -q alice
   ```

5. **Say:** nobody ran `create identity`. A user session leaves no key on the laptop. Disable alice in Keycloak and
   she's out.

## 8. bob, device certificate

1. **[claudevm]** ZDEW: **ADD IDENTITY** → **With URL** → paste:

   ```text
   https://addbyurl.zititv.demo.openziti.org:9480
   ```

2. Pick **Device certificate**. Sign in as `bob` / `bob-demo-pw`.
3. **[claudevm]** Paste:

   ```powershell
   curl.exe -s http://finance-ledger.acme.ziti
   ```

4. **[cdaws]** Paste:

   ```bash
   "$DEMO_DIR/bin/ziti" edge policy-advisor identities -q bob
   ```

5. **Say:** the key lives on the device. Works with nobody signed in and with Keycloak down. Disabling bob in Keycloak
   does not stop it. Disable the identity in OpenZiti.
6. **Say:** one device-cert identity per user. **Forget** removes it from the machine, not the controller.
7. Optional, **[cdaws]**:

   ```bash
   "$DEMO_DIR/bin/ziti" edge delete identity bob
   ```

### alice again, on the Mac

1. **[macos]** ZDEW: add identity with URL → paste:

   ```text
   https://addbyurl.zititv.demo.openziti.org:9480
   ```

2. Pick **User session**. Sign in as `alice` / `alice-demo-pw`.
3. **[macos]** Paste:

   ```bash
   curl -s http://eng-wiki.acme.ziti
   ```

4. **[cdaws]** Paste:

   ```bash
   "$DEMO_DIR/bin/ziti" edge list identities
   ```

5. **Say:** same URL, second machine, still one alice.

## 9. Groups are copied once

1. **Say:** groups are read when the identity is created, never again. After that, an admin owns the attributes.
2. Optional: Keycloak admin console → add alice to `finance`. Then **[cdaws]**:

   ```bash
   "$DEMO_DIR/bin/ziti" edge list identities
   ```

3. **Say:** alice still says engineering.

## 10. carol, from the command line

1. **[sg4]** browser: if it holds alice's Keycloak session, sign out:

   ```text
   https://addbyurl-idp.zititv.demo.openziti.org:9680/realms/acme/account
   ```

2. **[sg4]** Paste:

   ```powershell
   $zet = 'D:\tmp\ziti-tv-zet\1.19.1\ziti-edge-tunnel.exe'
   $ctrl = 'https://addbyurl.zititv.demo.openziti.org:9480'
   & $zet add -P ziti-tv -i carol -u $ctrl -m token
   & $zet ext-jwt-login -P ziti-tv -i carol -p acme-idp
   ```

3. Open the printed URL. Sign in as `carol` / `carol-demo-pw`.
4. **[sg4]** Paste:

   ```powershell
   & $zet dump -P ziti-tv
   ```

5. **[cdaws]** Paste:

   ```bash
   "$DEMO_DIR/bin/ziti" edge list identities
   ```

6. **Say:** `-m token` is a user session, `-m cert` a device cert. First login needs `-p` with the signer name. Same
   on Linux, with `sudo`.
7. **Say:** carol exists, no attributes, reaches nothing. Exactly what her groups say. Don't `curl` from SG4: alice's
   ZDEW answers for those names.

## Closing

1. **Say:** a URL and a sign-in. Identity at first login, access from IdP groups. User session for people, device
   cert for machines.
2. Paste the walkthrough link in chat.

---

## If it breaks live

| Symptom | Fix |
| --- | --- |
| `CLUSTER_NO_LEADER` | Controller just started. Wait a few seconds, retry. |
| Tunneler rejects the cert for `addbyurl` | Private cert claims the name. `--ctrl-address` must be `addbyurl-ctrl`. |
| JWT enroll `CONTROLLER_UNAVAILABLE` | CA bundle lacks LE roots. Rerun `patch-ctrl.sh`, restart controller. |
| bob or carol signs in as alice | Keycloak session. Sign out at `/realms/acme/account`. |
| `failed to start external auth` | First `ext-jwt-login` needs `-p acme-idp`. |
| `ENROLLMENT_IDENTITY_ALREADY_ENROLLED` | User exists. Drop `-m`, run `ext-jwt-login`. |
| Service does not answer | `tail $DEMO_DIR/host.log`. Is `run-host` up? |

## Reset

Users only (deletes alice, bob, carol, ends their Keycloak sessions, takes alice out of finance). Restart at step 7.
**[cdaws]**:

```bash
bash reset.sh
```

Everything except the cert. Restart at step 3. **[cdaws]**:

```bash
bash reset.sh all
```

Then **Forget** in every ZDEW.

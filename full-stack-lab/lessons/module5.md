# Module 5 - "Advanced auth"

> Identity itself is foundational and is introduced early (Module 1, module-1.e). This module is the
> ADVANCED authentication layer: passwords, MFA, bring-your-own-CA, revocation.

**Stage setup:** `bash scripts/stage.sh module-5` (full lab). Each episode maps to a script.

---

## module-5.a - Passwords and MFA (8 min)

**GOAL:** Identities can authenticate with username/password (UPDB), and services can require MFA.

**COLD OPEN:**
> "Not everything is a cert handed out by a token. Sometimes it's a human with a password, and for the sensitive
> stuff, a second factor."

**SAY / DO:**
- SAY: "UPDB: a username/password identity. Watch alice get a password and log in." DO:
  ```
  bash scripts/demo-updb.sh
  ```
  (creates alice with --updb, enrolls a password, logs in as alice)
- SAY: "MFA: a service that requires a second factor. Our client has no MFA, so it is denied." DO:
  ```
  docker exec zo-roamer-1 curl -s -o /dev/null -w "echo=%{http_code}\n" http://echo.ziti     # 200
  docker exec zo-roamer-1 curl -s http://mfa-echo.ziti                                        # reset/denied
  ```
- SAY: "Enroll TOTP on that identity (ziti edge enroll-mfa, scan the QR, verify a code) and the same dial
  succeeds. Posture re-checks continuously."

**TAKEAWAY:** "UPDB covers humans, MFA posture gates the crown jewels, the policy decides per-service whether a
second factor is required."

**DON'T SHOW:** the full TOTP QR flow end to end (mention it); the deny is the proof.

---

## module-5.b - Bring your own CA (8 min)

**GOAL:** Auto-enroll a fleet from your existing CA, no per-identity tokens.

**COLD OPEN:**
> "You already issue certs from a corporate CA. OpenZiti can trust it and auto-enroll anything it signs."

**SAY / DO:**
- SAY: "We generated a CA with Ziti's PKI tool and registered it for ottca + autoca." DO:
  ```
  bash scripts/provision-enrollment-demos.sh      # if not already done
  docker exec -it zo-ziti-controller1-1 ziti edge list cas
  ```
  (flags A=autoca O=ottca E=auth)
- SAY: "Verify the CA (prove we hold its key), then any client cert it signs auto-creates an identity on first
  connect." DO: walk `bash scripts/finish-ca.sh` (verification token -> sign a cert with CN=token -> verify ->
  issue a fleet cert -> connect -> identity auto-appears).

**TAKEAWAY:** "Register a CA once, then your existing PKI mints overlay identities for a whole fleet, zero
per-device token handling."

**DON'T SHOW:** deep x509 internals; keep it to register -> verify -> auto-enroll.

---

## module-5.c - Revocation (5 min)

**GOAL:** Killing an identity instantly revokes its access.

**COLD OPEN:**
> "Someone's laptop is stolen. How fast can you cut it off? Instantly."

**SAY / DO:**
- DO:
  ```
  bash scripts/demo-revocation.sh
  ```
  (creates `condemned`, shows it authorized, deletes it, shows it gone)
- SAY: "Delete the identity and its cert and live sessions die at once. For a softer touch, revoke a single cert
  by fingerprint with `ziti edge create revocation`."

**TAKEAWAY:** "Access is centrally controlled, revocation is immediate and total, no waiting for a firewall rule
to propagate."

**DON'T SHOW:** nothing extra, keep it short and punchy.

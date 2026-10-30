# Cloudflare setup, click by click

For someone who has never used Cloudflare. Menu names come from the Cloudflare docs on 2026-10-30. Cloudflare
renames menus often. If a name does not match, look for the closest one.

At the end you have five values. Keep them in a private note as you go, never in this folder:

| Value               | Example                                  | Goes into                       |
|---------------------|------------------------------------------|---------------------------------|
| zone                | `example.com`                            | `.env` `ZAB_HOST`, the docs     |
| team domain         | `mycorp.cloudflareaccess.com`            | `.env` `CF_TEAM_DOMAIN`, k8s    |
| `zab-local` token   | long string starting `eyJ`               | `zab/tunnel.token`              |
| `zab-k8s` token     | long string starting `eyJ`               | k8s secret                      |
| two AUD tags        | 64 hex characters each                   | `.env` `CF_AUD`, k8s            |

The tokens are secrets. Never paste them into chat, a commit, or the stream.

## 0. Before you start: you need a domain on Cloudflare

Cloudflare only publishes hostnames under a domain (a "zone") that it runs DNS for.

1. Go to <https://dash.cloudflare.com/> and sign in (or sign up).
2. The home page lists your domains. If you see one you can use, write it down as the zone and go to step 1.
3. If the list is empty, you need a domain. The fastest path is to buy one in Cloudflare: **Domain Registration**
   > **Register Domains**. A `.com` costs about 10 USD a year and is live in minutes. Adding a domain you already
   own elsewhere also works, but the nameserver change can take hours. Do not start that on show day.

## 1. Open Zero Trust and pick a team name

1. In the left menu, select **Zero Trust**.
2. The first time, Cloudflare asks for a **team name**. Pick something short, for example `zabdemo`. Your team
   domain is then `zabdemo.cloudflareaccess.com`. Write it down.
3. It asks for a plan. Choose **Free** (up to 50 users). It may ask for a payment card even for Free. That is
   normal and it does not charge.
4. Already done this once? The team name is under **Zero Trust** > **Settings**.

## 2. Turn on email sign-in (One-time PIN)

This lets anyone sign in with a code sent to their email. No Google or Okta needed.

1. **Zero Trust** > **Integrations** > **Identity providers**.
2. If **One-time PIN** is already listed under **Your identity providers**, skip to step 3.
3. Otherwise select **Add new identity provider**, then **One-time PIN**. Save.

## 3. Create the two tunnels

A tunnel is how Cloudflare reaches ZAB. ZAB dials out to Cloudflare, so nothing opens on your network. Do this
twice: once with name `zab-local`, subdomain `zab`; once with name `zab-k8s`, subdomain `k8s`.

1. **Networking** > **Tunnels** (in older menus: **Zero Trust** > **Networks** > **Tunnels**).
2. Select **Create a tunnel**. If it asks for a type, choose **Cloudflared**.
3. Name: `zab-local`. Select **Create Tunnel**.
4. The next page shows an install command, for example `cloudflared service install eyJhIjoi...`.
   **Do not run it.** ZAB runs the tunnel itself. Copy only the long string after `install` (or after `--token`).
   That is the tunnel token. Save it as the `zab-local` token.
5. Select **Continue** (or **Next**). The page may say the tunnel is not connected yet. That is expected.
6. Now add the hostname. On the tunnel, open the **Routes** tab (older menus: **Public Hostname** tab).
   Select **Add route**, then **Published application** (older: **Add a public hostname**).
   - **Subdomain**: `zab`
   - **Domain**: your zone from step 0
   - **Service URL**: `http://localhost:8080` (older: **Type** `HTTP`, **URL** `localhost:8080`). ZAB ignores this
     value, but the form needs one.
7. Select **Add route** (or **Save**).
8. Repeat steps 2 to 7 with name `zab-k8s` and subdomain `k8s`.

## 4. Create the two Access applications

An Access application is the login gate in front of a hostname. Do this twice: once for `zab.<zone>`, once for
`k8s.<zone>`.

1. **Zero Trust** > **Access controls** > **Applications** (older: **Access** > **Applications**).
2. Select **Create new application** (older: **Add an application**), then **Self-hosted and private** (older:
   **Self-hosted**).
3. **Application name**: `zab-local`.
4. Select **Add public hostname**. **Subdomain** `zab`, **Domain** your zone.
5. Under **Access policies**, select **Create new policy** (it may open in a new tab):
   - **Policy name**: `zab-local people`
   - **Action**: **Allow**
   - Under **Add rules**, **Include**: selector **Emails**, then type each address and press Enter:
     your email (plays alice), Andrew's email (plays bob), a third inbox you can read (plays carol). A plus address
     such as `you+carol@netfoundry.io` works if your mail delivers it.
   - Select **Save**. Go back to the application tab, refresh the policy list if needed, and select this policy.
6. **Login methods** (or identity providers): make sure **One-time PIN** is checked.
7. Select **Create** (or **Next** until **Save**).
8. Find the AUD tag: in the application list, select **Configure** on `zab-local`. Under **Additional settings**
   (or the **Overview** tab), copy **Application Audience (AUD) Tag**. Save it as the `zab-local` AUD.
9. Repeat steps 2 to 8 with name `zab-k8s`, subdomain `k8s`, and a policy with only your email and Andrew's.

## 5. Check before you leave the dashboard

- [ ] Two tunnels under **Networking** > **Tunnels**. Both say **Inactive** or **Down**. That is right: ZAB is
      not running yet.
- [ ] Two applications under **Access controls** > **Applications**.
- [ ] You have: zone, team domain, two tunnel tokens, two AUD tags.

Back to [morning.md](morning.md) step 2.

# Morning list: what needs Clint

Everything that needs a Cloudflare login, a real inbox, or a yes. In order. The rest is built and proven.

## 1. Cloudflare dashboard (one zone, about 15 minutes)

Never used Cloudflare? Follow [cloudflare.md](cloudflare.md) instead of this section. It is click by click.

Pick the zone. Everything below calls it `<zone>`.

1. **Zero Trust, Settings, Authentication:** One-time PIN is enabled.
2. **Zero Trust, Networks, Tunnels:** create two Cloudflared tunnels. Skip the connector install. Copy each token
   (the string after `--token`).
   - `zab-local`, public hostname `zab.<zone>`, service `http://localhost:8080` (never used).
   - `zab-k8s`, public hostname `k8s.<zone>`, same service value.
3. **Zero Trust, Access, Applications:** two Self-hosted applications, one per hostname. Two apps, not one, so each
   ZAB checks its own AUD. Each gets an Allow policy, Include, Emails:
   - `zab.<zone>`: your email (alice), Andrew's email (bob), a third inbox you read (carol). A plus address on
     your own mailbox works if Cloudflare delivers to it: try it in step 2.6.
   - `k8s.<zone>`: your email, Andrew's email.
4. Copy both **AUD tags** and the **team domain** (`<team>.cloudflareaccess.com`).

## 2. sg4: the embedded demo

The rehearsal from last night still runs on other ports (quickstart 21280, fakeaccess 28880, wiki 28080, ledger
28081). It does not collide with the show ports. Stop it when you are ready:

```powershell
# every rehearsal process has the ZAB worktree's scratch dir, or 28081, on its command line
Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -match 'claude-exploration|28081' } |
    Where-Object { $_.Name -match 'ziti|fakeaccess|demo-http|python' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Confirm }
```

Then, in Git Bash:

```bash
cd /d/worktrees/github/openziti-test-kitchen/ziti-tv/2026-oct-30/live-stream/2026/10-30
export PATH="$PWD/bin:$PATH"       # zab, demo-http-server and ziti 2.0.3 are already in bin/
# .env already exists with ZAB_HOST, CF_TEAM_DOMAIN and CF_AUD filled in. Do not copy default.env over it.
# set ZITI_PASSWORD, ALICE, BOB, CAROL
nano .env
set -a; source .env; set +a
mkdir -p zab && printf '%s' '<zab-local tunnel token>' > zab/tunnel.token

# 2.1 quickstart, its own terminal. ZITI_PASSWORD must match .env
ziti edge quickstart --home ./qs --password "$ZITI_PASSWORD"
```

```bash
# 2.2 second terminal: same cd, PATH and source lines as above, then
bash setup.sh
# 2.3 apps
demo-http-server --port "$WIKI_PORT" --cloudflare-team-domain "$CF_TEAM_DOMAIN" --cloudflare-aud "$CF_AUD" &
python -m http.server "$LEDGER_PORT" --bind 127.0.0.1 --directory ledger &
# 2.4 the bridge, its own terminal
zab --config zab/config.yml run
```

2.5. Cloudflare tunnel page: `zab-local` shows Healthy.
2.6. Private windows, one per person, `https://zab.<zone>/` and `/ledger/`. Expect alice wiki + ledger, carol 403.
Ask Andrew to try bob from his browser.
2.7. Rehearse the revoke once (README section 9), then re-grant. **Re-grant takes up to five minutes.** Do it early.

This is the first run against real Cloudflare. If 2.6 gives everyone `requester is not known to openziti`, check
`ziti edge list ext-jwt-signers`: the issuer must be exactly `https://<team>.cloudflareaccess.com`.

## 3. clintfips: the k8s demo

Start the lab with `Start-ClintFips.ps1` if it is stopped. Then follow **"Morning"** in
[k8s/k8s-status.md](../k8s/k8s-status.md) with the `zab-k8s` token and the `k8s.<zone>` AUD. Its step 2 sets the
Access emails on `k8s-user-full` (you) and `k8s-user-limited` (Andrew). Then check the kill-a-pod beat once: it has
not been proven.

## 4. The docs

- Replace `<zone>` in `../script-zab.md` with the real zone (and in `../socials.md` once you have the YouTube URL).
- `pwsh production/render-html.ps1 live-stream/2026/10-30/script-zab.md`
- Review `README.md`, `setup.sh`, `reset.sh`, the two slides and `.gitignore`. Nothing is committed.

## 5. Andrew

- Send him `../script-zab.md` "Andrew's questions". Ask which of 14, 16 and 17 he wants in public.
- He needs his email in the Access policies (step 1.3) and has to sign in once before air.

## 6. Announce (Friday morning, per production/announce.md)

- Thumbnail: done, `D:\git\github\openziti\branding\ziti-tv\oct-30-2026.jpg` (uncommitted). Review it.
- YouTube event `Ziti TV Oct 30 2026 - Your identity, past the tunnel`, then paste its URL into `../socials.md`.

## 7. One decision for you

ZAB bug found while building: with Bind `#all` (as in the ZAB README) every person's route table holds every
service, so an unauthorized person gets a 502 dial failure instead of a 403. The fix is to build routes only from
services the person can Dial. File it in ziti-access-bridge, or fix it before the show. The episode works around it
by binding only the router.

# The host script

The walkthrough README is for viewers. The host script is the run sheet for the person on camera. It sits next to the
README as `live-stream/<year>/<mm-dd>/script-<slug>.md`, follows the README step for step with the same numbers, and
is rendered with [render-html.ps1](render-html.ps1) so every command has a copy button:

```powershell
pwsh production/render-html.ps1 live-stream/<year>/<mm-dd>/script-<slug>.md
```

Where the README uses placeholders (`example.com`, `$DOMAIN`), the script uses the real values for the machines the
host uses that day, so every block pastes as is. It never holds a password. Passwords stay in `.env`.

## Rules

- **Terse bullets of facts, not lines to read.** The host knows the material and talks in their own words. Each step
  is a header, a few bullets of what happens and what to point at, and the commands. No "What / Why / Say / Do", no
  "Say:" lines, no paragraphs that explain the show to the host. On Oct 23 the What/Why/Say/Do format was rejected
  four times live before air.
- **Tag every block with the machine it runs on,** by its real name (`[cdaws]`, `[sg4]`, `[claudevm]`, `[m1mini]`).
  Put a table of the machines and their roles at the top.
- **A logins table at the top:** every user, password source, group, and the machine they sign in on. The host
  cannot sign in as a user whose password is not in front of them.
- **Live URLs.** Push the episode branch and merge it before air, so every link in the script and in the posts
  resolves on `main`.
- **The demo is built and running before air.** "Done ahead" is a list of things that are already true, not a list
  of things to do. If the episode builds something live, the payoff shown first runs on a second overlay with its own
  ports, so the live build cannot collide with it.
- **"Done ahead" numbering matches what happens first.** If steps 1 to 3 are off screen, the checklist says 1 to 3.
- **Commands the host types more than once go in a script,** such as `reset.sh`. Make it safe to rerun.
- **End with "If it breaks live"** (symptom, then fix, one row each) and **"Reset to the start"**.

## Template

````markdown
# Ziti TV run sheet: <title>

<Mon D, YYYY>, 11 AM ET · <host> · walkthrough: <link on main>

| Machine | Role | Tag |
| --- | --- | --- |
| <server> | <what runs there> | **[<server>]** |
| <client> | <who signs in there> | **[<client>]** |

| User | Password | Group | Signs in on |
| --- | --- | --- | --- |
| <user> | `.env` `<VAR>` | <group> | <client> |

## Done ahead (already true at 10:30)

- [x] <certificate and DNS in place>
- [x] Payoff overlay running on <ports>
- [x] Every client is clean: old identities forgotten, DNS cache flushed, browsers signed out.

**[<server>]** every new terminal:

```bash
cd <episode dir>
set -a; source .env; set +a
```

---

## 0. Payoff

- <client>: add by URL `<url>`, sign in as <user>
- <resource> opens

## 1. <README step 1 header>

- <fact to point at>
- <fact to point at>

**[<server>]**

```bash
<commands, with the day's real values>
```

## Closing

- Paste the walkthrough link in chat.
- Next week: <topic>

## If it breaks live

| Symptom | Fix |
| --- | --- |
| <message> | <fix> |

## Reset to the start

```bash
bash reset.sh
```
````

# How to produce a Ziti TV

Ziti TV goes live most Fridays at 11 AM ET on https://www.youtube.com/openziti. The audience sees thirty to sixty
minutes of someone building something real with OpenZiti, from an empty directory, with nothing faked. Getting there
takes a week of work. This guide is that week, and [production/](production/) holds the templates and tools for each
part of it.

The rule that makes the show work: **every demo is one the viewer can run afterward.** If it only works on the host's
laptop, it is not done.

## The kit

Every episode ships the same set of files. Know what goes where before you start.

| Artifact | Where it lives | Who it is for | How |
| --- | --- | --- | --- |
| Walkthrough `README.md` | `live-stream/<year>/<mm-dd>/` | Viewers, after the show | [walkthrough.md](production/walkthrough.md) |
| Scripts, `default.env`, compose files | Same directory, or `files/` and `stack/` under it | Viewers and the host | [walkthrough.md](production/walkthrough.md) |
| `reset.sh` | Same directory | Viewers and the host: run it again | [walkthrough.md](production/walkthrough.md) |
| Diagrams (`.drawio` + `.svg`) | Same directory | Viewers, and the screen share | |
| Host script `script-<slug>.md` | Same directory | The host, on camera | [host-script.md](production/host-script.md) |
| `socials.md` | Same directory | Twitter/X, Bluesky, Reddit, LinkedIn | [announce.md](production/announce.md) |
| Thumbnail | `openziti/branding` repo, `ziti-tv/<mon>-<dd>-<year>.jpg` | YouTube and every post | [thumbnail.md](production/thumbnail.md) |
| Bumper slide | `openziti/branding` repo, `ziti-tv/<year>-bumpers.pptx` | The stream intro and outro | |
| Season arc | `live-stream/<year>/season-arc.md` | Everyone: how this episode fits the run | |

The walkthrough and the host script are different documents. The walkthrough is addressed to a reader doing the work,
with no stage directions. The host script is for the person on camera. Do not merge them.

[render-html.ps1](production/render-html.ps1) turns any of the markdown into a page with a copy button on every code
block. Use it for the host script and the socials:

```powershell
pwsh production/render-html.ps1 live-stream/<year>/<mm-dd>/script-<slug>.md
```

## Monday: pick the payoff

Start from the moment the viewer remembers. Not "we configure an external JWT signer", but "alice pastes a URL, signs
in, and the wiki opens". Write that sentence first. Everything else in the episode exists to earn it.

Then answer four questions, the same four the season arc answers per episode:

1. **The payoff.** What is visible on screen when it works?
2. **The work.** What has to be built to produce it?
3. **The decision.** What choice gets made live, on camera, where the audience can follow the reasoning?
4. **The unspoken part.** What has to be said out loud because the demo cannot show it? (Why this is safe. What
   breaks it. What it does not protect against.)

If the episode belongs to an arc, read `season-arc.md` first. It inherits the stack the last episode left running, and
the next episode expects something from this one.

If an episode outgrows its slot, split it. A good topic cut in half is two episodes. On Oct 23, tunneled ACME (getting
the certificate through the overlay instead of an open port 80) became its own episode instead of a rushed segment.

## Tuesday and Wednesday: build it for real

Build the whole thing on a scratch machine, from nothing, the way a viewer would. Follow
[walkthrough.md](production/walkthrough.md) for the README and the scripts. In short:

- Real names and real trust wherever the reader needs them. If the reader needs a public IP and DNS records, say so up
  front and use them yourself.
- Every machine-specific value goes in `default.env`. Every repeated step goes in a script that is safe to rerun.
- Pin versions.
- Keep a failure log as you go. It becomes the Troubleshooting section.
- Prove every claim. If the README says "carol enrolls with no groups", something has enrolled carol with no groups.

Draw the diagram while the design is fresh. One picture of who trusts whom saves five minutes of hand-waving.

## Thursday: rehearse, then make it look good

**Rehearse.** Run the README end to end on a clean machine, following only what is written. Every place you had to
improvise is a bug in the README. Fix it and run again. Then run `reset.sh` and do it once more: that proves the
reset, and the reset is what saves the show when a step goes wrong live.

**Stage the demo box.** Move the last episode's state aside, put the certificate and DNS in place, and open the
ports. That is all in [demo-infra.md](production/demo-infra.md). It is a cooking show: the slow, one-time parts are
done ahead, and the host says so on camera.

**Write the host script.** [host-script.md](production/host-script.md) has the template: a run sheet of terse bullets
and commands per step, tagged with the machine they run on, with the day's real values, a logins table, a "done
ahead" checklist, an "if it breaks live" table and the reset.

**Build the demo for real, then leave it running.** By Thursday night the payoff works on the demo box, on its own
overlay and ports, and every client has signed in once. Friday morning is for posting, not building.

**Make the thumbnail.** [thumbnail.md](production/thumbnail.md) has the house style, the codex prompt and the checks.
Zoom in on the small text before you ship it.

**Update the bumper.** `ziti-tv/<year>-bumpers.pptx` in the branding repo holds one slide per episode: the TV-noise
layer, the date, the title, an "Episode Details" block and a top text layer. Duplicate the last slide, change the
date, title and details, and export.

## Friday morning: tell people

[announce.md](production/announce.md) has the order, the YouTube title format, and the voice rules for the posts:

1. Create the YouTube live event, `Ziti TV <Mon> <D> <YYYY> - <Title>`, with the thumbnail. It gives the live URL.
2. Write `socials.md` with that URL, render it, and post: Twitter/X, Bluesky, Reddit, LinkedIn.
3. At 10 AM ET, post the one-hour reminder.

## 10:30 AM ET: preflight

- [ ] Every item in the host script's "done ahead" checklist is `[x]`.
- [ ] Every client is clean: old identities forgotten, DNS cache flushed, browsers signed out.
- [ ] Terminals laid out as the host script says, with large fonts. A Mac over VNC is scaled up enough to read.
- [ ] Notifications are off. Password managers, `.env` files and token files are off screen.
- [ ] Browser tabs are open in order.
- [ ] Diagram ready to share. Bumper loaded. Thumbnail set on the YouTube event.
- [ ] Walkthrough link ready to paste into chat.

## 11:00 AM ET: go live

- Open with the payoff. Show where this ends in the first two minutes, then build it.
- Narrate the decision, not the typing. The viewer can read the command. Tell them why it is that command.
- When something breaks live, keep going. Debugging on camera is the best content the show makes. Say what you
  suspect, check it, fix it, and add it to Troubleshooting afterward.
- Watch the chat. Questions from viewers decide what gets explained twice.
- Close on what is next: the next episode in the arc, or the thing this one did not cover.

## After the show

- Fix every README gap the live run exposed. Once YouTube has captioned the stream, download the captions (see
  [captions.md](production/captions.md)), fix the product names, and check the README against what was said.
- File the bugs the show found, with the episode timestamp.
- Add the YouTube link to the walkthrough. Series parts link every episode in the series and mark the current one.
- Merge the episode PR, so the walkthrough link in the posts points at something on `main`.
- Tear down anything public that the demo left running: open ports, test users, DNS records made for the episode.
- Commit the thumbnail and bumper to the branding repo.
- Write down what to do differently next week, and fold it into this guide or [production/](production/).

## For AI assistants

The show is built with AI assistants. If you are one, this section is your brief.

**Read first:** this file, [walkthrough.md](production/walkthrough.md), and, for a dated episode, the season arc and
the previous episode's directory.

**What you are good for here:**

- **Building and testing.** Write the scripts, then run them on a scratch machine and report what happened. Never
  report a step as working that you did not see work. Say what was not tested.
- **Proving claims.** Before a sentence goes in the README, prove it, and write the evidence (versions, commands,
  output) to a report. Do it on unique ports and container names on a shared box, and clean up after.
- **Fresh-eyes review.** Read the walkthrough cold and list every step that only makes sense if you wrote it.
- **The host script** from the README, following [host-script.md](production/host-script.md).
- **Thumbnail drafts** with codex, following [thumbnail.md](production/thumbnail.md). Check the spelling yourself.
- **Socials and the YouTube description,** following [announce.md](production/announce.md) and its voice rules.

**Rules:**

- Do not commit, push or post. Leave changes in the working tree for the host to review.
- Never overwrite an image or a branding file. Save a new version next to it.
- Never print `.env`, passwords, JWTs or identity files. Never put them in a file that gets committed.
- Before a destructive step on a demo box (stopping processes, deleting state, editing DNS), say what you will do and
  get a yes. Move old state aside instead of deleting it.
- The time before a show is short. Give the host one recommendation, not a menu.

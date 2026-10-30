# Announcing an episode: YouTube, then socials

Order matters. The YouTube live event comes first, because every post links to it.

## 1. The YouTube event

Create the stream (restream it, if you use a restreaming service) and set the thumbnail from
[thumbnail.md](thumbnail.md).

Title format, exactly:

```text
Ziti TV <Mon> <D> <YYYY> - <Title>
```

For example `Ziti TV Oct 16 2026 - Taking tools from strangers` and `Ziti TV Oct 23 2026 - Joining a network with just
a URL`. Use the same title as the blog post when the episode has one.

Description template:

```text
<One line: the payoff, said the way a viewer would say it.>

<Two or three sentences: what the feature or idea is, and why someone would want it.>

Today we build it from nothing:
- <what gets built, one line each>
- <...>

Scripts and walkthrough: https://github.com/openziti-test-kitchen/ziti-tv
OpenZiti: https://openziti.io
```

The live event gives a URL like `https://youtube.com/live/<id>`. Every post below uses it.

## 2. The socials

Write them in `live-stream/<year>/<mm-dd>/socials.md`, one fenced `text` block per post, and render that file with
[render-html.ps1](render-html.ps1) so each post has a copy button. Post in this order:

1. Twitter / X, plus a reply that lists what gets built
2. Bluesky
3. Reddit (title and body)
4. LinkedIn

Then a short "live in one hour" reminder on Twitter and Bluesky at 10 AM ET.

### Voice rules

These came from editing the Oct 23 posts. Follow them on the first draft:

- **No emoji, no `•` bullets, no `→` arrows.** They read as machine-written. Use plain `-` lists and words.
- **Not only enterprise.** The audience includes homelabbers. Say "your identity provider's login", not "your
  company login".
- **The payoff first.** The first line is what the viewer gets ("Paste a URL. Sign in. You're on the network."), not
  what the feature is called.
- **Links that work today.** An episode directory that is not on `main` yet 404s. Link the repo root until it
  merges.
- **Limits:** Twitter 280 characters (a URL counts as 23), Bluesky 300 graphemes (a URL counts in full).
- **Tags:** Twitter `#ZeroTrust #OpenZiti #NetSec`, Bluesky a couple in lowercase, LinkedIn a longer list that can
  add `#AppSec`, `#OIDC` and topic tags. Reddit gets none.
- **Reddit:** lead with the technical substance. Check each subreddit's self-promotion rules first. Good fits:
  r/selfhosted, r/homelab, r/zerotrust, r/networking.

Count a Bluesky post before posting:

```powershell
$t = Get-Clipboard -Raw
[System.Globalization.StringInfo]::new($t).LengthInTextElements
```

### Template

````markdown
# Ziti TV socials: <Month D, YYYY>

Attach the thumbnail to every post: `<path to the jpg>`

## 1. Twitter / X

```text
<payoff line>

<one or two sentences: what we do today on Ziti TV>

Live at 11 AM ET: https://youtube.com/live/<id>

#ZeroTrust #OpenZiti #NetSec
```

Reply to it:

```text
What we build live:
- <item>
- <item>
```

## 2. Bluesky

```text
<same as Twitter, can run a little longer>

Live at 11 AM ET: https://youtube.com/live/<id>

#netsec #zerotrust
```

## 3. Reddit

Title:

```text
<what it is, in plain words> (live build today, 11 AM ET)
```

Body:

```text
<the problem today, in the reader's terms>

<what changes, and how it works>

On today's Ziti TV stream we set it up from scratch:

- <item>

Everything is scripted, and the walkthrough goes up in the ziti-tv repo: https://github.com/openziti-test-kitchen/ziti-tv

Live at 11 AM ET: https://youtube.com/live/<id>. The recording stays up after.
```

## 4. LinkedIn

```text
<the problem, one short paragraph>

<the change, one short paragraph>

Today on Ziti TV we build it end to end, live:

- <item>

Friday, <Month D>, 11 AM ET: https://youtube.com/live/<id>
Scripts and walkthrough: https://github.com/openziti-test-kitchen/ziti-tv

#ZeroTrust #OpenZiti #NetSec #AppSec <topic tags> #OpenSource
```

## Reminder (Twitter and Bluesky, 10 AM ET)

```text
Live in one hour: <the payoff in a phrase>. Bring questions.
https://youtube.com/live/<id>
```
````

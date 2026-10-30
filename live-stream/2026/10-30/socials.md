# Ziti TV socials: October 30, 2026

Attach the thumbnail to every post: `D:\git\github\openziti\branding\ziti-tv\oct-30-2026.jpg`

Walkthrough links go to the repo root, which works now. After
`live-stream/2026/10-30` merges, edit the YouTube description to link it. Paragraphs inside each post are one line on
purpose: YouTube keeps every line break you paste. LinkedIn drops them all on paste, so add them back by hand.

## 0. Restream: schedule the event

Open https://studio.restream.io/start-event. Restream creates the YouTube live event. Its live URL is in YouTube
Studio, Content, Live: https://studio.youtube.com

| Field | Value |
| --- | --- |
| Title | the YouTube title below. Replace Restream's default "Live with Restream, October 30" |
| Description | the YouTube description below |
| Date | Oct 30, 2026 |
| Time (America/New_York) | 11:00 AM |
| Create an event post in advance | checked |
| Set calendar invite duration | optional |
| Thumbnail | Upload `D:\git\github\openziti\branding\ziti-tv\oct-30-2026.jpg` |

Then **Next, select channels**: pick YouTube and every other channel the show goes to.

YouTube title:

```text
Ziti TV Oct 30 2026 - Your identity, past the tunnel
```

YouTube description:

```text
Same URL, three people, three different answers, and the server opens no inbound port: the apps listen on 127.0.0.1 only.

Cloudflare Access proves who you are at the front door, then the tunnel hands your request to a connector, and from there the network sees only the connector's IP. Ziti Access Bridge (ZAB) carries it the rest of the way: it runs the Cloudflare Tunnel, checks the Access JWT, and signs in to OpenZiti as you. OpenZiti service policy then decides what you reach.

Today, with Andrew Martinez, we walk through it end to end:
- A Cloudflare Tunnel and Access app in front of two apps on 127.0.0.1
- An OpenZiti external JWT signer that trusts Cloudflare's tokens
- Three people who all pass Cloudflare and get three different answers
- Taking access away mid-session, live
- The same bridge in Kubernetes: two replicas, no Ingress, no LoadBalancer, no NodePort

Ziti Access Bridge: https://github.com/openziti-test-kitchen/ziti-access-bridge
Scripts and walkthrough: https://github.com/openziti-test-kitchen/ziti-tv
OpenZiti: https://openziti.io
```

## 1. Twitter / X

Open https://x.com/compose/post. Post this, then reply to it with the second post.

```text
Your login shouldn't stop at the tunnel.

Today on Ziti TV, we'll sign in using Cloudflare Access, and use it to connect over an OpenZiti service. Same URL, three people, three answers.

Live at 11 AM ET: https://youtube.com/live/ZSy4Gdl4tiM

#ZeroTrust #OpenZiti #NetSec #Cloudflare
```

Reply to it:

```text
What we show live:
- Cloudflare Tunnel + Access in front of two apps on 127.0.0.1
- OpenZiti trusting Cloudflare's JWT
- per-person access, revoked mid-session
- the same thing in Kubernetes with no Ingress, LoadBalancer or NodePort
```

## 2. Bluesky

Open https://bsky.app/intent/compose

```text
Your login shouldn't stop at the tunnel.

Today on Ziti TV, we'll sign in using Cloudflare Access, and use it to connect over an OpenZiti service. Same URL, three people, three answers.

Live at 11 AM ET: https://youtube.com/live/ZSy4Gdl4tiM

#netsec #zerotrust #openziti #cloudflare
```

## 3. Reddit

Post to r/openziti only: https://www.reddit.com/r/openziti/submit

Title:

```text
Keeping the user's identity past Cloudflare Tunnel, so the network behind it can tell people apart (live build today, 11 AM ET)
```

Body:

```text
Cloudflare Access checks who you are, then Cloudflare Tunnel hands the request to a connector. From there on every user looks the same: the connector's IP. Whatever sits behind it can only use IP and port rules.

Ziti Access Bridge (ZAB) is a small Go proof of concept that runs the tunnel itself, verifies the Access JWT, and signs in to an OpenZiti overlay with that same JWT, as that user. OpenZiti service policy then decides which apps each person reaches, and the apps listen on 127.0.0.1 only.

On today's Ziti TV stream we walk through the whole setup:

- a Cloudflare Tunnel and Access app, with Keycloak as the login
- an OpenZiti quickstart with an external JWT signer for Cloudflare
- three people who all pass Cloudflare and get three different answers
- revoking access mid-session
- the same bridge in Kubernetes, two replicas, no Ingress, LoadBalancer or NodePort

Ziti Access Bridge: https://github.com/openziti-test-kitchen/ziti-access-bridge

Everything is scripted, and the walkthrough goes up in the ziti-tv repo: https://github.com/openziti-test-kitchen/ziti-tv

Live at 11 AM ET: https://youtube.com/live/ZSy4Gdl4tiM. The recording stays up after.
```

## 4. LinkedIn

Open https://www.linkedin.com/feed/?shareActive=true

```text
Your login shouldn't stop at the tunnel.

Today at 11 AM ET on Ziti TV, Andrew Martinez and I sign in using Cloudflare Access, and use it to connect over an OpenZiti service. Same URL, three people, three different answers, each one decided by that person's own identity.

Live: https://youtube.com/live/ZSy4Gdl4tiM

Normally Cloudflare Access proves who you are, then the tunnel hands your request to a connector, and the network behind it only sees the connector's IP. Ziti Access Bridge verifies the Access JWT and signs in to OpenZiti as you, so OpenZiti service policy and ZAB's logs are per person, not per tunnel.

What we show, live:

- Cloudflare Tunnel and Access in front of two apps that listen on loopback only
- OpenZiti trusting Cloudflare's JWT through an external JWT signer
- revoking one person's access mid-session
- the same bridge in Kubernetes with no Ingress, LoadBalancer or NodePort

Ziti Access Bridge: https://github.com/openziti-test-kitchen/ziti-access-bridge
Scripts and walkthrough: https://github.com/openziti-test-kitchen/ziti-tv

#ZeroTrust #OpenZiti #NetSec #AppSec #Cloudflare #Kubernetes #OpenSource
```

## 5. Discourse

Open https://openziti.discourse.group/new-topic. Discourse keeps line breaks and renders markdown. Leave the YouTube
URL on its own line so it embeds the video.

Title:

```text
Ziti TV today, 11 AM ET: your Cloudflare Access login, all the way to OpenZiti services
```

Body:

```text
Your login shouldn't stop at the tunnel.

Today at 11 AM ET on Ziti TV, we'll sign into Cloudflare Access, and use it to connect over an OpenZiti service. Same URL, three people, three different answers.

[Ziti Access Bridge (ZAB)](https://github.com/openziti-test-kitchen/ziti-access-bridge) is a small Go proof of concept. It runs the Cloudflare Tunnel itself, verifies the Access JWT, and authenticates to OpenZiti with that same JWT through an [external JWT signer](https://openziti.io/docs/learn/core-concepts/security/authentication/external-jwt-signers), as that person. Service policy then decides which apps each person reaches, and the apps listen on 127.0.0.1 only.

What we show, live:

- a Cloudflare Tunnel and Access app, with Keycloak as the login
- an OpenZiti quickstart with an external JWT signer for Cloudflare
- three people who all pass Cloudflare and get three different answers
- revoking one person's access mid-session
- the same bridge in Kubernetes, two replicas, no Ingress, LoadBalancer or NodePort

https://youtube.com/live/ZSy4Gdl4tiM

Scripts and walkthrough: https://github.com/openziti-test-kitchen/ziti-tv. The recording stays up after the stream. Questions welcome here after the fact or in the live chat on YouTube.
```

## 6. 10 AM ET reminder (Twitter and Bluesky)

Open https://x.com/compose/post and https://bsky.app/intent/compose

```text
Live in one hour: one URL, three people, three answers, and your identity past the tunnel. Bring questions.
https://youtube.com/live/ZSy4Gdl4tiM
```

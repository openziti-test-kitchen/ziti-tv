# Episode 1: give the Appetizer the classifier it has been calling since 2023

Every message the [OpenZiti Appetizer](https://openziti.io/docs/learn/appetizer/) reflects goes through a call to an
offensive-speech classifier, and that call has never succeeded. This episode builds the missing piece: a classifier
that the Appetizer reaches as an OpenZiti service, with no IP address, no open port and nothing listening on TCP. None
of the Appetizer's code changes.

You end up with:

- The Appetizer's network: a controller, an edge router and the Appetizer, in docker compose.
- An identity for Ziggy, and a client that talks to the Appetizer's reflect server as Ziggy.
- A classifier hosting `classifier-service`, which blocks an insult and passes a compliment.
- One policy change that cuts the Appetizer off from the classifier while both keep running.

This is the first of four episodes, and each one starts from the stack the one before it leaves running. Episode 1
needs only Docker, git and curl. It needs no API key, no zrok account and no Python on the host. It is the compose
version of Joey's [original walkthrough](https://github.com/AccordionGuy/openziti-appetizer-classifier), which builds
the same thing inside an Appetizer clone.

The steps are in [LAB.md](LAB.md). This page explains what they show.

## The pieces

| Piece | What it is | Where it runs |
| --- | --- | --- |
| Controller | Holds the network's identities, services and policies, and decides who may dial or host what. | `quickstart` container |
| Edge router | Carries the traffic. Clients and hosts connect out to it; nothing connects in to them. | `router` container |
| Appetizer | A demo web app. It hands out identities and hosts `local_reflectService`, which echoes what you type. | `appetizer` container |
| Classifier | A small web API around an offensive-speech model. It hosts `classifier-service`. | `classifier` container |
| Reflect client | Dials `local_reflectService` as Ziggy, so you can type messages. | `reflect`, run on demand |
| `./.ziti` | The controller's PKI and database, and the classifier's identity file. | bind mount in `stack/` |
| `~/.ziti-demo` | Ziggy's identity file. | your home directory |

An identity is a private key and a certificate. A service is a name, not an address. A policy says which identities
may dial a service and which may host it.

## What you do

1. Start the controller, the router and the Appetizer, with no classifier.
2. Get an identity for Ziggy and send messages through the reflect server. Every message passes with a note that it
   can't be checked.
3. Ask the controller why: the service the Appetizer dials does not exist.
4. Create that service and its policies with the `ziti` CLI, then start the classifier.
5. Show that the classifier listens on no port, and that it now blocks an insult.
6. Change one policy to cut the Appetizer off, and change it back.

## The call that never succeeded

The Appetizer's reflect server checks every message in two stages. A local profanity filter runs first, in
[`overlay/reflectServer.go`](https://github.com/openziti-test-kitchen/appetizer/blob/main/overlay/reflectServer.go)
around line 128. Anything that passes it is POSTed, in `IsOffensive` around line 240, to:

```go
url := "http://classifier-service:80/api/v1/classify"
```

When that call fails, the message is relayed anyway, with a note that it can't be qualified. The name
`classifier-service` has no `local_` prefix while every other name the Appetizer creates does, which looks like the
bug. It is not. `local_demo-server`, the Appetizer's own identity, carries a bare `classifier-clients` attribute next to
its prefixed ones. The Appetizer tags itself in
[`underlay/httpServer.go`](https://github.com/openziti-test-kitchen/appetizer/blob/main/underlay/httpServer.go)
around line 60. One classifier for every instance was the plan, so the bare URL is correct.

What is missing is on the controller: there is no `classifier-service`, and no policy lets `#classifier-clients` dial
anything. The Appetizer has been dialing a service that does not exist, and reporting that correctly.

## Four objects and no code

| Object | Why |
| --- | --- |
| An identity for the classifier | Every process on the network needs one. |
| A service named `classifier-service` | The name the Appetizer dials has to resolve. |
| A bind policy | Only the classifier's identity may host the service. |
| A dial policy for `#classifier-clients` | The Appetizer may call it, through the attribute it already carries. |

Policies match by tag, with `#`, rather than by name. A second classifier needs only an identity tagged
`classifier-servers`, and a second Appetizer is a caller as soon as its identity carries `classifier-clients`.

The Appetizer hands an identity to anyone who types a name on its web page, as a one-time enrollment token, and
enrolling the token generates the key locally. Ziggy is OpenZiti's mascot, and her
identity is the one every later episode uses.

## Dark means the host does not know

A terminator is the network's record that something is hosting a service right now. Once the classifier runs,
`classifier-service` has a terminator, and the classifier container has no listening socket: the network knows the
classifier is there, and the host operating system does not.

The classifier is a Flask app served by waitress. The `@openziti.zitify` decorator in [`classifier.py`](classifier.py)
replaces the socket calls, so when waitress binds `0.0.0.0:18080`, the bind becomes an OpenZiti service bind. Flask's
own development server does not work here: it never accepts connections on a ziti socket.

The model, `cardiffnlp/twitter-roberta-base-offensive`, labels text `offensive` or `non-offensive`. The Appetizer
compares against the string `Offensive`, so `classifier.py` maps the label by set membership. A substring test would
flag every clean message, because `non-offensive` contains `offensive`.

The model catches direct insults. It passes `nobody here wants you around and everyone knows it` as clean. Episode 2
gives it a second opinion for exactly these.

## Fail open, and a denied service looks missing

When the classifier is stopped, the Appetizer relays everything with the `can't be qualified` note. Moderation that is
unreachable lets everything through. That is the application's decision, not the network's.

Revoking the dial policy gives the Appetizer `service 'classifier-service' not found`, the same error it got before the
service existed. The service exists, it runs and it has a terminator, and the Appetizer cannot tell the difference. A
service you may not dial is not shown to you at all.

Revoking takes effect at once, because the controller ends sessions the policy no longer allows. Restoring waits for
the Appetizer's next service refresh, which took about three and a half minutes in testing.

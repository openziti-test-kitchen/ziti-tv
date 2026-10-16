# Episode 1 lab: the classifier

The steps for [episode 1](README.md). The README explains what each step shows.

The commands are tagged **[ubuntu]** because the series is recorded on WSL. On Linux and macOS it is all one shell.
Use three shells, all in the `stack` directory: one for commands, one for the client, and one for logs. Each block
says which.

## 1. Get the files and build the images

Everything for all four episodes is in this repository's `live-stream/2026/10-16/stack` directory, as one docker
compose project named `ziti-tv`.

**[ubuntu]** commands

```sh
git clone https://github.com/openziti-test-kitchen/ziti-tv.git
cd ziti-tv/live-stream/2026/10-16/stack

cp default.env .env
# episode 1's classifier decides alone. Episode 2 removes this line and gives it a second opinion
echo 'CLASSIFIER_GATEWAY_URL=' >> .env

docker compose build
```

The placeholder keys in `.env` are fine until episode 2. `ZITI_PWD` is the controller's admin password, `admin` by
default. Change it before the first start if anything but your machine can reach the controller: the quickstart sets it
once, when it creates the network.

The build installs CPU-only PyTorch and bakes the model weights into the classifier image, so the first build takes
several minutes and nothing downloads at runtime. It also builds the image the clients in this and later episodes run
in.

## 2. Start a network that has no classifier

**[ubuntu]** commands

```sh
docker compose up -d --wait appetizer      # the controller, then the router, then the Appetizer
docker compose ps -a
```

`ps` lists `init-ziti-dir` as `Exited (0)`, and `quickstart`, `router` and `appetizer` as `Up`. `init-ziti-dir` hands
`./.ziti` to the user the ziti containers run as. `./.ziti` is the whole network: the controller's PKI, its database
and every identity.

## 3. Get an identity for Ziggy

The client in the next step needs an identity to dial anything. `createIdentity.sh` does what the Appetizer's web form
does: it asks the Appetizer for an identity named `ziggy`, downloads the one-time enrollment token, and enrolls it
inside the quickstart container, which has the ziti CLI.

**[ubuntu]** commands

```sh
./createIdentity.sh ziggy                  # wrote ~/.ziti-demo/local_ziggy.json
```

The name gets a `local_` prefix because this Appetizer runs as instance `local`. Every service it creates carries the
same prefix.

To see the page itself, open **http://localhost:18000/** in a browser. It also shows each message the reflect server
relays, in its lower right corner.

## 4. See the gap

**[ubuntu]** client

```sh
docker compose run --rm reflect
```

The client loads `local_ziggy.json` and dials `local_reflectService` by name. Type each line and press Enter:

```text
you are a delight
```

The reply is `you sent a message, but it can't be qualified at this time for offensiveness: you are a delight`.

Then type an English swear word. The reply is `please remember to be kind and keep it clean. not sending your
message.` A word-list filter caught it before any classifier was asked.

Leave the client running.

## 5. Ask the controller what is missing

The Appetizer dials `classifier-service` for every message that passes its word filter. See what the controller has.

**[ubuntu]** commands

```sh
# logs in as admin with ZITI_PWD from .env. The login is kept inside the quickstart container, so later commands need
# no login
./login.sh

docker compose exec quickstart ziti edge list identities
docker compose exec quickstart ziti edge list services
docker compose exec quickstart ziti edge list service-policies
```

`local_demo-server`, the Appetizer's own identity, carries `local_demo.servers` and a bare `classifier-clients`. The
services are `local_httpService` and `local_reflectService`, and the policies cover only those two. There is no
`classifier-service`, and no policy lets `#classifier-clients` dial anything.

## 6. Build the network side

Four objects make the call work: an identity, a service, a bind policy and a dial policy. Each command runs in the
`quickstart` container, which mounts `./.ziti` as `/ziti`.

**[ubuntu]** commands

```sh
# the classifier's identity, tagged classifier-servers, enrolled at once. The classifier container reads
# ./.ziti/classifier.json
docker compose exec quickstart ziti edge create identity classifier-service-host \
  -a classifier-servers -o /ziti/classifier.jwt
docker compose exec quickstart ziti edge enroll /ziti/classifier.jwt -o /ziti/classifier.json

# the service, tagged classifier-services
docker compose exec quickstart ziti edge create service classifier-service -a classifier-services

# bind: only identities tagged classifier-servers may host it
docker compose exec quickstart ziti edge create service-policy classifier-service-bind Bind \
  --identity-roles '#classifier-servers' --service-roles '#classifier-services'

# dial: identities tagged classifier-clients may call it. The Appetizer's identity already carries the tag
docker compose exec quickstart ziti edge create service-policy classifier-service-dial Dial \
  --identity-roles '#classifier-clients' --service-roles '#classifier-services'

# the Appetizer reads its service list at start and refreshes it only every few minutes
docker compose restart appetizer
docker compose exec quickstart ziti edge list terminators
```

The terminator table has two rows, `local_httpService` and `local_reflectService`. `classifier-service` exists and the
Appetizer may dial it, but nothing hosts it.

The restart dropped the client. In the client shell, run `docker compose run --rm reflect` again and send
`you are a delight`: the reply still says it can't be qualified.

## 7. Start the classifier

**[ubuntu]** commands

```sh
docker compose up -d classifier
docker compose logs classifier             # run again if it is empty: the model is still loading
```

Two lines matter:

```text
model cardiffnlp/twitter-roberta-base-offensive labels: {0: 'non-offensive', 1: 'offensive'}
binding ziti service classifier-service as /identity/classifier.json
```

The first shows the labels `classifier.py` maps to the Appetizer's `Offensive`. The second means the classifier has
joined the network and hosts `classifier-service`.

## 8. Confirm it is dark

**[ubuntu]** commands

```sh
docker compose exec classifier ss -ltn
docker compose exec quickstart ziti edge list terminators
```

`ss` shows one listener, on `127.0.0.11`. That is Docker's embedded DNS resolver, which every container has. Nothing
listens on 18080 or on any other port. The terminator table now has a third row, `classifier-service`.

## 9. Use it

**[ubuntu]** logs

```sh
docker compose logs -f classifier
```

Keep the logs and the client side by side. In the client, send each of these:

| Send | Client reply | Classifier log |
| --- | --- | --- |
| `you are a delight` | `you sent me: you are a delight` | `clean by=classifier {'label': 'non-offensive', 'score': 0.88...}` |
| an English swear word | `please remember to be kind and keep it clean. not sending your message.` | nothing |
| `you are too stupid to understand this` | `Your message seems like it might be offensive. We didn't relay it.` | `OFFENSIVE by=classifier {'label': 'offensive', 'score': 0.90...}` |

The swear word never reaches the model: the word filter stops it first.

Now stop the classifier and send the insult again:

**[ubuntu]** commands

```sh
docker compose stop classifier
```

The insult comes back as `can't be qualified at this time`, and the Appetizer relays it.

**[ubuntu]** commands

```sh
docker compose start classifier
```

The log stream ended when the container stopped. Run `docker compose logs -f classifier` again in the logs shell, and
wait for `binding ziti service classifier-service` before you send anything else.

## 10. Revoke access with one policy change

**[ubuntu]** commands

```sh
# the dial policy now matches identities tagged nobody, and there are none
docker compose exec quickstart ziti edge update service-policy classifier-service-dial --identity-roles '#nobody'
```

In the client, send `hello, world` once, then the insult. The insult comes back as `can't be qualified` again. The
classifier is still running, and nothing at either end was restarted.

**[ubuntu]** commands

```sh
docker compose logs appetizer | grep -i classif | tail -2
```

The last line ends with `service 'classifier-service' not found`, the same error as before step 6.

Restore the policy:

**[ubuntu]** commands

```sh
docker compose exec quickstart ziti edge update service-policy classifier-service-dial \
  --identity-roles '#classifier-clients'

# skip the wait for the Appetizer's next service refresh, then reconnect the client
docker compose restart appetizer
```

The insult is blocked again.

## Where this leaves you

Leave the stack running. Episode 2 starts from here: it removes the `CLASSIFIER_GATEWAY_URL=` line from `.env` and gives
the classifier a second opinion from an LLM, through LLM Gateway.

To stop, run `docker compose down`. It keeps `./.ziti`, so `docker compose up -d --wait router` and
`docker compose up -d appetizer classifier` bring back the same network, with Ziggy's identity still valid.

To start this episode over from an empty network:

**[ubuntu]** commands

```sh
docker compose --profile '*' down
docker run --rm -v "$PWD":/stack busybox rm -rf /stack/.ziti   # owned by the container's user, so delete it from one
rm -f ~/.ziti-demo/local_ziggy.json                            # issued by the old network, so it no longer works
```

## Troubleshooting

**`router` or `appetizer` shows `Restarting` or `Exited (1)` right after the first start.** The controller answers its
health check before it has created the admin user, so a first login can get `401 Unauthorized`. Both containers restart
on failure and log in on the next try. If one stays down, run `docker compose up -d router appetizer`. If it keeps
failing with `401`, `ZITI_PWD` in `.env` changed after the network was created. Set it back, or start over.

**The client prints `NO_EDGE_ROUTERS_AVAILABLE`.** The router is not running. Check `docker compose ps -a router` and
`docker compose logs router`.

**The client prints `has no terminators` for `local_reflectService`.** The Appetizer started before the router was up,
or it is still starting after a restart, so nothing hosts the reflect service yet. Wait until
`docker compose ps appetizer` shows `(healthy)` and reconnect. If it does not, run `docker compose restart appetizer`.

**`createIdentity.sh` says the Appetizer returned no enrollment token.** The Appetizer is not up yet. Wait until
`docker compose ps appetizer` shows `(healthy)`, and repeat step 3.

**The client fails with a certificate error after you started over.** `local_ziggy.json` was issued by the network you
deleted. Delete it and repeat step 3.

**`service 'classifier-service' not found` after step 6 or after restoring the policy.** The Appetizer has not
refreshed its service list yet. Run `docker compose restart appetizer`, or wait a few minutes.

**An offensive message gets a clean verdict.** If you changed `CLASSIFIER_MODEL`, its labels may differ. Compare the
`labels:` line in the classifier log with `OFFENSIVE_LABELS` in `compose.yml`.

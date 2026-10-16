# Episode 3 lab: MCP Gateway and the agent

The steps for [episode 3](README.md). The README explains what each step shows.

The commands are tagged **[ubuntu]** because the series is recorded on WSL, and **[brave]** for the browser. On Linux
and macOS the commands are all one shell. All shells are in the `stack` directory: commands, client, the classifier's
log from episode 1, and two new ones for MCP Gateway's log and the agent's. Each block says which.

## 1. Start from where episode 2 ended

**[ubuntu]** commands

```sh
cd ziti-tv/live-stream/2026/10-16/stack
docker compose ps -a
docker compose exec classifier printenv GATEWAY_URL    # http://llm-gateway:8080

set -a; . ./.env; set +a
GATEWAY=127.0.0.1:${GATEWAY_PORT:-8080}
. ep2-llm-gateway/helpers.sh
judge "nobody here wants you around and everyone knows it"
```

`ps` lists `quickstart`, `router`, `appetizer`, `classifier`, `ollama` and `llm-gateway` as `Up`, and `judge` prints
`claude-haiku-4-5-20251001 → OFFENSIVE`. If not, do [episode 2's lab](../ep2-llm-gateway/LAB.md) first.

Rebuild the runtime image. Its copy of `zrok2` is new in this episode:

**[ubuntu]** commands

```sh
docker compose build llm-gateway           # the image every service but the classifier runs
```

## 2. Call the first tool as Ziggy

The Appetizer's math service has been on the network since 2023. Send it one HTTP request, over a connection dialed
by service name.

**[ubuntu]** commands

```sh
# dial.py hangs up when its input ends, so the sleep keeps it open for the reply
{ printf 'GET /domath?input1=6&operator=%%2A&input2=7 HTTP/1.0\r\nHost: math\r\n\r\n'; sleep 5; } \
  | docker compose run --rm -T reflect python /episode4/byo/dial.py local_httpService
```

The reply is an HTTP response that ends with `Result: 42.00`. The request names a service, `local_httpService`, not a host or a port.

## 3. Get a zrok environment and a closed share

MCP Gateway listens on no port. It serves through a zrok share, and agents reach it by the share's name.

**[brave]**

Sign up for zrok as the [zrok getting-started guide](https://docs.zrok.io/docs/getting-started/) describes, and copy
your account token.

**[ubuntu]** commands

```sh
# one time per machine. It writes ~/.zrok2, which mcp-gateway and agent mount
docker compose run --rm --no-deps mcp-gateway zrok2 enable <your-account-token>
docker compose run --rm --no-deps mcp-gateway zrok2 status     # Account Token and EnvZId <<SET>>
```

If `zrok2` on the host has already enabled an environment, skip `enable`. If it lives somewhere other than `~/.zrok2`,
set `ZROK2_DIR` in `.env`.

Pick a share name: 3 to 32 lowercase letters, digits and hyphens, not taken by anyone else.

**[ubuntu]** commands

```sh
SHARE=pick-your-own-name
sed -i "s|^SHARE=.*|SHARE=${SHARE}|" .env
docker compose run --rm --no-deps mcp-gateway zrok2 create share -s "$SHARE"     # created share '...'
```

The share is closed by default: only your own zrok account can reach it.

## 4. Give the tools and the agent identities and policies

The tool server dials the services as `appetizer-tools`. The agent hosts `agent-service` as `agent-service-host`.

**[ubuntu]** commands

```sh
# the tool server's identity, enrolled into ./.ziti, where mcp-gateway reads it
docker compose exec quickstart ziti edge create identity appetizer-tools -o /ziti/appetizer-tools.jwt
docker compose exec quickstart ziti edge enroll /ziti/appetizer-tools.jwt -o /ziti/appetizer-tools.json

# one dial policy per tool, so each tool can be taken away on its own
docker compose exec quickstart ziti edge create service-policy math-tool-dial Dial \
  --identity-roles '@appetizer-tools' --service-roles '@local_httpService'
docker compose exec quickstart ziti edge create service-policy classify-tool-dial Dial \
  --identity-roles '@appetizer-tools' --service-roles '@classifier-service'

# the agent's identity and its own service
docker compose exec quickstart ziti edge create identity agent-service-host -o /ziti/agent.jwt
docker compose exec quickstart ziti edge enroll /ziti/agent.jwt -o /ziti/agent.json
docker compose exec quickstart ziti edge create service agent-service
docker compose exec quickstart ziti edge create service-policy agent-service-bind Bind \
  --identity-roles '@agent-service-host' --service-roles '@agent-service'

# every identity the Appetizer hands out, Ziggy's included, may talk to the agent
docker compose exec quickstart ziti edge create service-policy agent-service-dial Dial \
  --identity-roles '#local_demo.clients' --service-roles '@agent-service'

docker compose exec quickstart ziti edge list service-policies 'name contains "tool" or name contains "agent"'
```

The list shows the four policies. If a `ziti` command says the session expired, repeat episode 1's step 5.

## 5. Prove the tools with no gateway

`check.py` starts the tool server as a child process, lists its tools over stdio and calls each one once.

**[ubuntu]** commands

```sh
docker compose run --rm --no-deps -e ZITI_IDENTITY=/ziti/appetizer-tools.json agent \
  python ep3-mcp-gateway/tools/check.py
```

Among the log lines:

```text
tools: ['classify', 'math']
math: ok -> Result: 42.00
classify: ok -> OFFENSIVE
```

The classifier log shows `OFFENSIVE by=classifier ... :: you are too stupid to understand this`. Only a program that
starts the tool server itself can use these tools so far.

## 6. Put MCP Gateway in front of the tools

**[ubuntu]** commands

```sh
docker compose up -d mcp-gateway
```

**[ubuntu]** mcp-gateway log

```sh
docker compose logs -f mcp-gateway
```

Wait for `discovered tools from backends` with `"tool_count":2`, and `serving mcp over zrok share`. Then run the same
check through `mcp-tools`, zrok and the gateway:

**[ubuntu]** commands

```sh
docker compose run --rm --no-deps -e MCP_SHARE="$SHARE" agent python ep3-mcp-gateway/tools/check.py gateway
```

```text
tools: ['appetizer_classify', 'appetizer_math']
appetizer_math: ok -> Result: 42.00
appetizer_classify: ok -> OFFENSIVE
```

The gateway log has one `tool call succeeded` line per call, with its arguments. The `unable to dispatch msg received
for unknown edge conn id` lines from `mcp-tools` are harmless.

To see the operator's menu at work, change the last line of `ep3-mcp-gateway/mcp-gateway.yml` to `list: ["math"]` and
run `docker compose restart mcp-gateway`. The log says `"tool_count":1`. Change it back to `list: ["math", "classify"]`
and restart again.

## 7. Send one tool-calling request with the agent's key

**[ubuntu]** commands

```sh
ask gemma3:4b hi "$AGENT_GATEWAY_KEY"      # refused: the agent's key is for tool calls only

curl -s "$GATEWAY/v1/chat/completions" \
  -H "Authorization: Bearer $AGENT_GATEWAY_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"auto","max_tokens":200,
       "messages":[{"role":"user","content":"what is 6 times 7? use the tool"}],
       "tools":[{"type":"function","function":{"name":"appetizer_math",
         "description":"Exact arithmetic on two numbers. operator is one of: + - * /",
         "parameters":{"type":"object","properties":{"input1":{"type":"number"},"operator":{"type":"string"},
           "input2":{"type":"number"}},"required":["input1","operator","input2"]}}}]}' \
  | jq '{model, tool_calls: .choices[0].message.tool_calls}'
```

The `curl` returns `"model": "claude-haiku-4-5-20251001"` and one tool call to `appetizer_math` with
`{"input1":6,"operator":"*","input2":7}`. LLM Gateway translated Claude's answer into an OpenAI-style tool call.

## 8. Run the agent at a prompt

**[ubuntu]** commands

```sh
docker compose run --rm agent python ep3-mcp-gateway/agent/agent.py --cli
```

Wait for `tools offered by the gateway: appetizer_classify, appetizer_math` and the `you>` prompt. Ask each:

```text
what is 6 * 7
is "you are too stupid to understand this" offensive?
is "nobody here wants you around and everyone knows it" offensive?
```

For the first, the agent logs each step:

```text
  [cli] model=claude-haiku-4-5-20251001
  [cli] tool appetizer_math({'input1': 6, 'operator': '*', 'input2': 7}) -> Result: 42.00
  [cli] model=claude-haiku-4-5-20251001
agent> 6 * 7 = 42
```

The other two both call `appetizer_classify` and both come back offensive. The classifier log shows they got there
differently: `by=classifier` for the first, `by=claude-haiku-4-5-20251001` for the second. In the second, Claude called
a tool that asked Claude.

Exit with **Ctrl-D**.

## 9. Make the agent a dark service

**[ubuntu]** commands

```sh
docker compose up -d agent
docker compose exec quickstart ziti edge list terminators     # agent-service is now one of the rows
```

**[ubuntu]** agent log

```sh
docker compose logs -f agent               # wait for: bound agent-service as /ziti/agent.json
```

In the client shell, stop the reflect client with **Ctrl-C** and dial the agent instead:

**[ubuntu]** client

```sh
docker compose run --rm dial
```

The agent log shows `connection from local_ziggy`. Send `what is 6 * 7`. The reply is `6 * 7 = 42`, and the agent log
shows the same steps as at the prompt, tagged `[local_ziggy]`.

## 10. Take the tool away

Keep the commands shell, the client and the agent log in view.

**[ubuntu]** commands

```sh
docker compose exec quickstart ziti edge delete service-policy math-tool-dial
```

In the client, send `what is 6 * 7` again. The reply says the math tool failed. The agent log shows:

```text
  [local_ziggy] REFUSED appetizer_math({'input1': 6, 'operator': '*', 'input2': 7}) -> ... the connection to local_httpService was dropped ...
```

Give it back:

**[ubuntu]** commands

```sh
docker compose exec quickstart ziti edge create service-policy math-tool-dial Dial \
  --identity-roles '@appetizer-tools' --service-roles '@local_httpService'
```

Send `what is 6 * 7` once more. The first try right after the restore can still fail, with `service not available` in
the agent log: the tool server learns that it may dial the service again on its next service refresh. Within a minute
or two the reply is `6 * 7 = 42`. Nothing restarted.

## Where this leaves you

Leave the stack running. [Episode 4](../ep4-byo-tools/README.md) starts from here: strangers bring their own tools to
the agent.

To stop, run `docker compose down`. `docker compose up -d --wait llm-gateway` and
`docker compose up -d appetizer classifier mcp-gateway agent` bring it back. The share keeps its name.

## Troubleshooting

**`docker compose run ... zrok2` says `executable file not found`.** The runtime image predates this episode. Run
`docker compose build llm-gateway`.

**`zrok2 create share` says the name is taken.** Share names are global. Pick another, and update `SHARE` in `.env`.

**`mcp-gateway` exits right after it starts.** It could not open the share, or a backend failed while it listed tools.
Check `docker compose logs mcp-gateway`: a share error means `SHARE` in `.env` is not a share you created, or
`~/.zrok2` is not enabled. A backend error means `./.ziti/appetizer-tools.json` is missing: repeat step 4.

**`check.py gateway` or the agent hangs, then fails to connect.** MCP Gateway is not serving yet, or `mcp-gateway` and
`mcp-tools` come from different releases. Wait for `serving mcp over zrok share`. Both come from the same release in
`runtime.Dockerfile`.

**The agent container keeps restarting.** It started before MCP Gateway was serving the share. It restarts on failure
and connects once the gateway is up.

**`agent-service` is not in the terminator list.** The agent is not running, or crashed after binding. Check
`docker compose logs agent`.

**The `dial` client prints `has no terminators` for `agent-service`.** Same cause. Start the agent with
`docker compose up -d agent`.

**The agent answers `(llm-gateway refused: ...)`.** The agent's key is not allowed the route or model the request
reached. Check its `allowed_routes` and `allowed_models` in `ep2-llm-gateway/llm-gateway.yml`, and that
`AGENT_GATEWAY_KEY` in `.env` is the key the gateway started with.

**A tool call still succeeds right after you delete its policy.** The change had not reached the network yet. Ask again
after a few seconds.

**The math tool still fails with `service not available` after you restore the policy.** Revoking takes effect at
once. Restoring waits for the tool server's next service refresh. Ask again in a minute or two.

**Claude answers 42 after you delete the policy.** It did the arithmetic itself. The network still refused the call:
the agent log shows `REFUSED`. Ask about numbers it cannot do in its head.

**A `ziti` command fails with `the cached access token has expired`.** The admin session timed out. Repeat episode 1's
step 5.

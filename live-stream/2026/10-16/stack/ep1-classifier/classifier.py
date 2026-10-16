"""A text classifier hosted as a dark OpenZiti service.

Speaks the contract the appetizer's reflect server already expects:

    POST /api/v1/classify  {"text": "..."}
    200                    [{"label": "Offensive", "score": 0.97}]

Nothing listens on TCP. openziti.zitify intercepts the web server's bind and
turns it into an OpenZiti service bind, so the only way to reach this process
is to be an identity authorized to dial CLASSIFIER_SERVICE.

Served with waitress, which is what the OpenZiti Python SDK's Flask sample
uses. If you swap in an async server, see the SDK's ziti-uvicorn sample - an
event-loop server needs a little more than a decorator.

Episode 2 adds a second opinion. When the classifier calls a message clean but
is less than ESCALATE_BELOW sure, it asks llm-gateway, which decides which LLM
answers. Leave GATEWAY_URL unset and this file behaves exactly as in episode 1.
"""

import http.client
import json
import os
import socket
from urllib.parse import urlsplit

import openziti
from flask import Flask, jsonify, request
from transformers import pipeline

MODEL = os.getenv("CLASSIFIER_MODEL", "cardiffnlp/twitter-roberta-base-offensive")
THRESHOLD = float(os.getenv("CLASSIFIER_THRESHOLD", "0.5"))
IDENTITY = os.getenv("ZITI_IDENTITY", "/identity/classifier.json")
SERVICE = os.getenv("CLASSIFIER_SERVICE", "classifier-service")
BIND_HOST = "0.0.0.0"
BIND_PORT = 18080

pipe = pipeline("text-classification", model=MODEL)

# Printed at startup so you can see what this model actually emits. Few models
# emit the literal string "Offensive" that the reflect server compares against,
# and a mismatch is silent - see OFFENSIVE_LABELS below.
print(f"model {MODEL} labels: {pipe.model.config.id2label}", flush=True)

# Set from the environment to match the loaded model. Membership is exact and
# not a substring test, because "non-offensive" contains "offensive" and a
# substring test would flag every clean message.
OFFENSIVE_LABELS = {
    label.strip().lower()
    for label in os.getenv(
        "OFFENSIVE_LABELS", "offensive,toxic,hate,label_1"
    ).split(",")
    if label.strip()
}

# Episode 2: when the classifier isn't sure, ask llm-gateway for a second
# opinion. Leave GATEWAY_URL unset and this file behaves exactly as in episode 1.
GATEWAY_URL = os.getenv("GATEWAY_URL", "").rstrip("/")
GATEWAY_KEY = os.getenv("GATEWAY_KEY", "")
ESCALATE_BELOW = float(os.getenv("ESCALATE_BELOW", "0.9"))
MODERATOR_PROMPT = (
    "You moderate a public chat. Decide whether the user's message is "
    "offensive: insulting, demeaning, exclusionary, or hostile toward a "
    "person or group. Reply with exactly one word: OFFENSIVE or CLEAN."
)


# Captured at import, before openziti.zitify patches the socket module.
# openziti 1.7.1's patched create_connection builds its plain-TCP fallback
# socket with the wrong address family, so ordinary outbound HTTP inside
# zitify fails with "a bytes-like object is required, not 'tuple'".
# The original create_connection works, so the gateway call uses it.
_PLAIN_CREATE_CONNECTION = socket.create_connection


def second_opinion(text):
    """Ask whichever model the gateway routes to. None means keep our verdict."""
    body = json.dumps({
        "model": "auto",     # the gateway chooses the model, not this code
        "max_tokens": 5,     # one word, and a ceiling on what a call can cost
        "temperature": 0,
        "messages": [
            {"role": "system", "content": MODERATOR_PROMPT},
            {"role": "user", "content": text},  # routing embeds only this
        ],
    }).encode()
    url = urlsplit(GATEWAY_URL)
    conn = http.client.HTTPConnection(url.hostname, url.port or 80, timeout=30)
    conn._create_connection = _PLAIN_CREATE_CONNECTION  # see the note above
    try:
        conn.request("POST", "/v1/chat/completions", body=body, headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {GATEWAY_KEY}",
        })
        resp = conn.getresponse()
        raw = resp.read().decode()
    except Exception as e:  # gateway or backend down
        print(f"escalation failed, keeping classifier verdict: {e}", flush=True)
        return None
    finally:
        conn.close()
    if resp.status != 200:  # 401, 403, spend cap, model missing
        print(f"escalation refused ({resp.status}): {raw[:200]}", flush=True)
        return None
    try:
        reply = json.loads(raw)
        word = reply["choices"][0]["message"]["content"].strip().upper()
    except Exception as e:
        print(f"escalation reply unreadable, keeping classifier verdict: {e}", flush=True)
        return None
    return "OFFENSIVE" in word, reply.get("model", "?")


app = Flask(__name__)


@app.post("/api/v1/classify")
def classify():
    body = request.get_json(force=True, silent=True) or {}
    text = (body.get("text") or "").strip()

    # The reflect server indexes results[0] without a length check, so an empty
    # array crashes the connection handling on its side. Never return [].
    if not text:
        return jsonify([{"label": "Not offensive", "score": 1.0}])

    top = pipe(text, truncation=True)[0]
    score = float(top["score"])
    offensive = top["label"].strip().lower() in OFFENSIVE_LABELS and score >= THRESHOLD
    decided_by = "classifier"

    # Only clean-but-unsure verdicts escalate. A confident "offensive" stands,
    # and profanity never gets here: goaway rejects it in the appetizer first.
    if GATEWAY_URL and not offensive and score < ESCALATE_BELOW:
        opinion = second_opinion(text)
        if opinion is not None:
            offensive, decided_by = opinion

    print(f"{'OFFENSIVE' if offensive else 'clean'} by={decided_by} {top} :: {text}", flush=True)

    return jsonify([{
        "label": "Offensive" if offensive else "Not offensive",
        "score": round(float(top["score"]), 4),
    }])


@app.get("/healthz")
def healthz():
    return "ok"


@openziti.zitify(bindings={
    f"{BIND_HOST}:{BIND_PORT}": {"ztx": IDENTITY, "service": SERVICE},
})
def serve_over_ziti():
    from waitress import serve
    print(f"binding ziti service {SERVICE} as {IDENTITY}", flush=True)
    # The port exists only because web servers require one. Nothing binds it on
    # the host; the OpenZiti service name is the real address.
    serve(app, host=BIND_HOST, port=BIND_PORT)


if __name__ == "__main__":
    serve_over_ziti()

# Shell helpers for talking to the gateway. Source this, don't run it:
#
#   . gateway/helpers.sh
#
# Running it with sh, bash or ./ defines the functions in a child shell that
# exits immediately, and you get "command not found: ask".

GATEWAY="${GATEWAY:-127.0.0.1:8080}"

# ask <model> <text> [key]: prints the model the gateway bound, then the reply or the error
ask() {
  local auth=()
  [ -n "$3" ] && auth=(-H "Authorization: Bearer $3")
  curl -s "$GATEWAY/v1/chat/completions" \
    -H "Content-Type: application/json" "${auth[@]}" \
    -d "$(jq -n --arg m "$1" --arg t "$2" '{model:$m, max_tokens:30, messages:[{role:"user", content:$t}]}')" \
  | jq -r '(.model // "error") + " → " + (.choices[0].message.content // .error.message)'
}

# Keep this identical to MODERATOR_PROMPT in classifier/classifier.py
MODERATOR_PROMPT="You moderate a public chat. Decide whether the user's message is offensive: insulting, demeaning, exclusionary, or hostile toward a person or group. Reply with exactly one word: OFFENSIVE or CLEAN."

# judge <text>: the exact request the classifier sends when it escalates
judge() {
  curl -s "$GATEWAY/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $CLASSIFIER_GATEWAY_KEY" \
    -d "$(jq -n --arg t "$1" --arg s "$MODERATOR_PROMPT" '{model:"auto", max_tokens:5, temperature:0, messages:[{role:"system", content:$s}, {role:"user", content:$t}]}')" \
  | jq -r '(.model // "error") + " → " + (.choices[0].message.content // .error.message)'
}
